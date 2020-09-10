require! {
  \prelude-ls : {
    map
    filter
    flatten
    any
    keys
    unique
  }
  child_process : { exec }
  async : {
    map : async-map-uncurried
    map-series : async-map-series-uncurried
    series : async-series-uncurried
  }
  path : {
    join  : join-path-uncurried
  }
  fs : {
    stat: stat-file-uncurried
    readdir
    access
    constants
    mkdir
  }
}


#
#
export say = -> console.log(it);it



#
#
export stat-file = (path, callback) -->
  stat-file-uncurried(path, (err, result) ->
    if err?
      callback(err)
    else
      result.path = path
      callback(null, result)
    )



#
#
export async-map = (collection, iteratee, callback) -->
  async-map-uncurried collection, iteratee, callback



#
#
export async-map-series = (collection, iteratee, callback) -->
  async-map-series-uncurried collection, iteratee, callback



#
#
export async-series = (tasks, callback) -->
  async-series-uncurried tasks, callback



#
#
export join-path = (a, b) --> join-path-uncurried(a,b)



#
#
export F = (fail, fn, success) -->
  fn (err, result) ->
    if err?
      fail err
    else
      success result



#
#
export parse-json = (text, fn) -->
  result = try
    fn null, JSON.parse(text)
  catch {message}
    fn message



#
#
export find-path-for-file = (name, path, fn) -->
  err <- access name, constants.F_OK
  if err?
    fn(err)
  else
    fn(null, path)



#
#
export read-dir = (path, fn) --> readdir(path, fn)



#
#
export walk-dir = (path, test, done) -->
  const f = F (error) -> done(error)

  files <- f(read-dir(path))

  paths = files
  |> map join-path path

  stats <- f(async-map(paths, stat-file))

  valid-entries = stats
  |> map (stat) ->
    is-directory : stat.is-directory!
    path : stat.path
  |> filter test

  handle-entry = (entry, fn) ->
    if entry.is-directory
      walk-dir entry.path, test, fn
    else
      fn null, entry.path

  files <- f(async-map-series(valid-entries, handle-entry))

  done(null, files |> flatten)



#
#
export ensure-path = (path, done) -->
  mkdir(path, {recursive:true}, done)





