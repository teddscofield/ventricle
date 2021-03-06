_fs       = require 'fs'
_path     = require 'path'
_util     = require 'util'
_events   = require 'events'
emitters  = new Object

console  =
  debug: (message, args...) -> # _util.debug _util.format message, args...
  log:   (message, args...) -> _util.log   _util.format message, args...

# Return the existing EventEmitter or create one
emitter = (path) ->
  unless emitters[path]?
    try
      console.debug 'watch %s', path
      emitters[path]   = new _events.EventEmitter()
      emitters[path].w = _fs.watch path, (event, file) ->
        if e = emitters[path]
          _fs.stat path, (err, info) ->
            unless err?.code == 'ENOENT'
              console.debug 'emit %s %s', event, path
              e.emit event, path, err, info
  emitters[path]

unlisten = (path, callback) ->
  if e = emitters[path]
    console.debug 'unlisten %s', path

    if callback
      e.removeListener 'change', callback
      e.removeListener 'rename', callback
    else
      e.removeAllListeners 'change'
      e.removeAllListeners 'rename'

    unless e.listeners('change').length
      e.w?.close()
      delete emitters[path]

class Listener
  constructor: (callback) ->
    @listening = new Object
    @callback  = (path, err, info) =>
      console.debug 'callback %s %j', path, err

      delete @listening[path] if err?
      callback path, err, info

  watchFile: (path) ->
    return if @listening[path]
    console.debug 'watchFile %s', path
    @listening[path] = true

    e = emitter path
    e.on 'change', @callback
    e.on 'rename', @callback

  unwatchFile: (path) ->
    delete @listening[path]
    unlisten path

  watchDir: (dir) ->
    return if @listening[dir]
    @listening[dir] or= new Object

    updateDir = (quiet) => () =>
      console.debug 'compareDir %s', dir

      complete = 0
      current  = new Object

      _fs.readdir dir, (err, list) =>
        for path in (_path.join(dir, file) for file in list)
          do (path) =>
            _fs.stat path, (err, info) =>
              if info?.isFile()
                current[path] = info
                compareFile path, info, quiet
              if list.length == complete += 1
                checkRemoved current
                @listening[dir] = current

    compareFile = (path, current, quiet) =>
      console.debug ' compareFile %s', path

      previous = @listening[dir]
      a = current.mtime.getTime()
      b = previous[path]?.mtime?.getTime()

      unless b
        console.debug '  created %s', path
        this.watchFile path
        @callback path, null, current unless quiet
      else if current.ino is not previous[path].ino
        console.debug '  replaced %s', path
        @callback path, null, current

    checkRemoved = (current) =>
      console.debug ' checkRemoved %s', dir

      for path, info of @listening[dir]
        unless current[path]
          console.debug '  removed %s', path
          this.unwatchFile path
          @callback path, true, null

    e = emitter dir
    e.on 'change', updateDir(false)
    e.on 'rename', updateDir(false)
    updateDir(true)()

  unwatchDir: (dir) ->
    null

  watchTree: (dir) ->
    _fs.readdir dir, (err, list) =>
      return unless list
      this.watchDir dir

      for path in (_path.join(dir, file) for file in list)
        do (path) =>
          _fs.stat path, (err, info) =>
            this.watchTree path if info?.isDirectory()

  unwatchTree: (dir) ->
    null

exports = module.exports =
  platform: 'kqueue'
  Listener: Listener
