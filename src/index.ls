require! {
  \prelude-ls : {
    map
    filter
    flatten
    any
    keys
    unique
    first
  }
  child_process : { exec }
  path : {
    extname
    basename
    dirname
    resolve : resolve-path
  }
  fs : {
    read-file
  }
  \./lib : {
    say
    F
    stat-file
    async-map
    async-map-series
    async-series
    join-path
    parse-json
    find-path-for-file
    read-dir
    walk-dir
    ensure-path
  }
}




# open-config
#
open-config = (name, path, fn) -->
  err, data <- read-file "#path/#name", \utf8
  if err?
    fn(err)
  else
    fn(null, data)



# exec-command
#
exec-command = (pass, file, done) -->
  # Extract file extension
  const type = pass.types[file.type]

  if not type?
    done "error: pass filetype '#{file.type}' does not exist"

  else
    cmd = type.cmd
      .replace(/{{out-file}}/g, file.out-file)
      .replace(/{{out-path}}/g, file.out-path)
      .replace(/{{in-file}}/g, file.in-file)

    # Print the command to execute
    say cmd
    exec cmd, (error, stdout, stderr) ->
      if error?
        say cmd
        say error
        done(error)

      else
        process.stdout.write stdout
        process.stderr.write stderr
        done null


# exec-merge-command
#
# {
#   "mode"  : "merge",
#   "input" : "./build",
#   "output" : "./dist/app.js",
#   "ignore" : ["node_modules"],
#   "types": {
#     ".js" : {
#       "outext" : ".js",
#       "cmd" : "find {{in-path}} -name '*.js' -exec cat {} + > {{out-file}}"
#     }
#   }
# }
exec-merge-command = (pass, file, done) -->
  # Extract file extension
  const type = pass.types[file.type]

  if not type?
    done "error: pass filetype '#{file.type}' does not exist"

  else
    cmd = type.cmd
      .replace(/{{in-path}}/g, pass.input)
      .replace(/{{out-file}}/g, pass.output)

#     # Print the command to execute
    say cmd
    exec cmd, (error, stdout, stderr) ->
      if error?
        say cmd
        say error
        done(error)

      else
        process.stdout.write stdout
        process.stderr.write stderr
        done null


# test-changed
#
is-file-changed = (a, b, done) -->
  # Setup error handeler
  no-a-file = F (error) -> done(error)
  # stats <- f(async-series([stat-file(a), stat-file(b)]))

  stat-a <- no-a-file(stat-file(a))

  no-b-file = F (error) ->
    done null, true

  stat-b <- no-b-file(stat-file(b))

  done null, stat-a.mtime-ms > stat-b.mtime-ms


find-entries = (pass, done) -->
  # Setup error handeler
  const f = F (error) -> done(error)
  # Resolve path for pass input
  const full-path = resolve-path pass.input

  # Define valid file extension names
  types = pass.types |> keys

  # Setup entry test
  test-path = (entry) ->
    if entry.is-directory
      const name = basename(entry.path)
      not (pass.ignore |> any (== name))

    else
      # Extract file extension
      const ext = extname(entry.path)
      # Test if extension match any type
      types |> any (== ext)


  # Walk dir
  result <- f(walk-dir(full-path, test-path))

  done null, result



build-file-info = (pass, file, callback) -->
  # Setup error handeler
  const f = F (error) -> callback(error)

  # Resolve path for pass input
  const full-path = resolve-path pass.input

  const ext = extname(file)
  const relative = file.replace(new RegExp("^#full-path"), '')

  out-path = relative
  |> join-path(pass.output)
  |> resolve-path
  |> dirname

  out-basename = basename(file)
    .replace(new RegExp(ext + '$', ''), pass.types[ext].outext)

  const out-file = join-path(out-path, out-basename)

  const info =
    in-file  : file
    out-file : out-file
    relative : relative
    out-path : out-path
    type     : ext

  callback null, info


# passes
#
passes =
  # convert
  #
  convert:  (pass, done) -->
    # Setup error handeler
    const f = F (error) -> done(error)

    files <- f(find-entries(pass))
    entries <- f(async-map-series(files, build-file-info(pass)))
    paths <- f(async-map-series(entries, (entry, callback) ->
      const f = F (error) -> callback(error)

      is-changed <- f(is-file-changed(entry.in-file, entry.out-file))

      new-entry = entry <<< changed: is-changed

      callback null, new-entry
      ))

    changed = paths
    |> filter (.changed)

    dirs = changed
    |> map (.out-path)
    |> unique

    <- f(async-map(dirs, ensure-path))
    <- f(async-map(changed, exec-command(pass)))

    say "nothing to do" if changed.length == 0

    done null, "DONE"

  # merge
  #
  merge: (pass, done) -->
    # Setup error handeler
    const f = F (error) -> done(error)

    files <- f(find-entries(pass))
    entries <- f(async-map-series(files, build-file-info(pass)))
    paths <- f(async-map-series(entries, (entry, callback) ->
      const f = F (error) -> callback(error)

      is-changed <- f(is-file-changed(entry.in-file, pass.output))

      new-entry = entry <<< changed: is-changed

      callback null, new-entry
      ))

    changed = paths
    |> filter (.changed)
    |> first

    <- f(ensure-path(dirname(pass.output)))

    if changed?
      <- f(exec-merge-command(pass, changed))
      done null, "DONE"
    else
      say "nothing to do"
      done null, "DONE"


# run-pass
#
run-pass = (pass, done) -->
  say "running pass: #{pass.mode}"
  passes[pass.mode](pass, done)

# run
#
run = (config-file, start-dir, fn) ->
  # Setup error handeler
  f = F (error) -> fn(error)

  # Find first config file
  path <- f(find-path-for-file(config-file, start-dir))
  say "Found config in: #path/#config-file"

  # Read config file
  text <- f(open-config(config-file, path))

  # Parse config as JSON
  config <- f(parse-json(text))

  # Map through passes in config
  <- f(async-map-series(config.passes, run-pass))


  fn null, \success



config-file = "pipe.conf"
start-dir = process.cwd!

err, result <- run config-file, start-dir

if err?
then say err
else say result

