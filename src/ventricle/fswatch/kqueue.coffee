define (require, exports, module) ->
  _fs       = require 'fs'
  _path     = require 'path'
  _util     = require 'util'
  _events   = require 'events'
  emitters  = new Object

  # Return the existing EventEmitter or create one
  emitter = (path) ->
    unless emitters[path]?
      try
        _util.debug _util.format('watch %s', path)
        emitters[path]   = new _events.EventEmitter()
        emitters[path].w = _fs.watch path, (event, file) ->
          if e = emitters[path]
            _fs.stat path, (err, info) ->
              unless err?.code == 'ENOENT'
                _util.debug _util.format('emit %s %s', event, path)
                e.emit event, path, err, info
    emitters[path]

  unlisten = (path, callback) ->
    if e = emitters[path]
      _util.debug _util.format('unlisten %s', path)
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
        _util.debug _util.format('callback %s %j', path, err)
        delete @listening[path] if err?
        callback path, err, info

    watchFile: (path) ->
      return if @listening[path]
      _util.debug _util.format('watchFile %s', path)
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
        _util.debug _util.format('compareDir %s', dir)
        complete = 0
        current  = new Object

        _fs.readdir dir, (err, list) =>
          for path in (_path.join(dir, file) for file in list)
            ((path) =>
              _fs.stat path, (err, info) =>
                if info?.isFile()
                  current[path] = info
                  compareFile path, info, quiet
                if list.length == complete += 1
                  checkRemoved current
                  @listening[dir] = current) path

      compareFile = (path, current, quiet) =>
        _util.debug _util.format(' compareFile %s', path)
        previous = @listening[dir]
        a = current.mtime.getTime()
        b = previous[path]?.mtime?.getTime()

        if not b
          _util.debug _util.format('  created %s', path)
          this.watchFile path
          @callback path, null, current unless quiet
        else if current.ino is not previous[path].ino
          _util.debug _util.format('  replaced %s', path)
          @callback path, null, current

      checkRemoved = (current) =>
        _util.debug _util.format(' checkRemoved %s', dir)
        for path, info of @listening[dir]
          unless current[path]
            _util.debug _util.format('  removed %s', path)
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
          ((path) =>
            _fs.stat path, (err, info) =>
              this.watchTree path if info?.isDirectory())(path)

    unwatchTree: (dir) ->
      null

  exports.Listener = Listener
  exports
