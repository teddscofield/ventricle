define (require, exports, module) ->
  _fs       = require 'fs'
  _path     = require 'path'
  _util     = require 'util'
  _events   = require 'events'
  emitters  = new Object

  # Return the existing EventEmitter or create one
  emitter = (path) ->
    unless emitters[path]?
      emitters[path] = new _events.EventEmitter()
      _fs.watch path, (event, file) ->
        if e = emitters[path]
          _util.debug _util.format('emit %s %s', event, _path.join(path, file))
          e.emit event, _path.join(path, file)
    emitters[path]

  unlisten = (path, callback) ->
    if e = emitters[path]
      e.removeListener 'change', callback
      e.removeListener 'rename', callback
      unless e.listeners('change').length
        delete emitters[path]

  class Listener
    constructor: (callback) ->
      @callback  = callback
      @listening = new Object

    watchFile: (path, quiet) ->
      return if @listening[path]
      _util.debug _util.format('watchFile %s', path)
      @listening[path] = true

      e = emitter path
      e.on 'change', @callback
      e.on 'rename', @callback
      @callback path unless quiet

    watchDir: (dir) ->
      _util.debug _util.format('watchDir? %s', dir)
      return if @listening[dir]
      _util.debug _util.format('watchDir! %s', dir)

      update = (quiet) => () =>
        _util.debug _util.format('watchDir/ %s', dir)
        _fs.readdir dir, (err, list) =>
          return unless list
          for path in (_path.join(dir, file) for file in list)
            ((path) =>
              _fs.stat path, (err, info) =>
                this.watchFile path, quiet if info and info.isFile()) path

      e = emitter dir
      e.on 'change', update(false)
      e.on 'rename', update(false)
      this.watchFile dir, true
      update(true)()

    unwatchDir: (dir) ->
      null

    watchTree: (dir) ->
      _fs.readdir dir, (err, list) =>
        return unless list
        this.watchDir dir

        for path in (_path.join(dir, file) for file in list)
          ((path) =>
            _fs.stat path, (err, info) =>
              this.watchTree path if info and info.isDirectory())(path)

    unwatchTree: (dir) ->
      null

    autoWatch: (dir) ->
      auto = new Listener (path) =>
        _fs.stat path, (err, info) =>
          if info and info.isDirectory()
            auto.watchTree path
          else
            @callback path
      auto.watchTree dir

  exports.Listener = Listener
  exports
