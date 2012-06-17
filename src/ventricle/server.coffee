_fswatch  = require './fswatch'
_io       = require 'socket.io'
_fs       = require 'fs'
_qs       = require 'querystring'
_url      = require 'url'
_http     = require 'http'
_util     = require 'util'
_path     = require 'path'
_events   = require 'events'

emitters = new Object
sockets  = new Object
mounted  = new Object

console  =
  debug: (message, args...) -> # _util.debug _util.format message, args...
  log:   (message, args...) -> _util.log   _util.format message, args...

jsOk = (res, message, code = 200) ->
  res.writeHead code, 'Content-Type': mime 'response.js'
  res.end JSON.stringify status: 'ok', message: message

jsErr = (res, message, code = 400) ->
  res.writeHead code, 'Content-Type': mime 'response.js'
  res.end JSON.stringify status: 'error', message: message

app = (port) -> (req, res) ->
  # Parse the requested URL and its query string
  url = _url.parse 'http://' + req.headers.host + req.url, true

  console.log '%s', url.href

  # Request is not for the config app?
  unless test = /^\/ventricle($|\/.*$)/.exec url.pathname
    unless fspath = resolve url.host, url.pathname
      return jsErr res, 'not file', 404

    return sendfile res, fspath

  # Dealing with config app from here down
  resources = _path.join __dirname, '..', '..', 'resources'
  urlpath   = test[1]
  urlpath   = '/index.html' if not urlpath or urlpath is '/'

  if test  = /^\/checkdir\/(.*)$/.exec urlpath
    fspath = test[1]
    checkdir res, _path.join '/', fspath

  else if test = /^\/checkurl\/([^/]+)(.*)$/.exec urlpath
    host    = test[1]
    urlpath = test[2]
    checkurl res, host, urlpath

  else if /^\/sites/.test urlpath
    config res, req, url

  else
    sendfile res, _path.join(resources, urlpath)

checkdir = (res, fspath) ->
  fspath = _path.resolve fspath

  _fs.readdir fspath, (err, children) ->
    if err?
      return jsErr res, path: fspath, code: err.code, 404

    # Filter hidden files and directories
    children = (x for x in children when x[0] isnt '.')

    files    = []
    dirs     = []
    count    = children.length

    unless count
      # Empty directory, respond immediately
      return jsOk res, path: fspath, files: files, dirs: dirs

    for child in children
      do (child) ->
        _fs.stat _path.join(fspath, child), (err, info) ->
          if info?.isDirectory()
            dirs.push child
          else if info?.isFile()
            files.push child

          unless count -= 1
            jsOk res, path: fspath, files: files, dirs: dirs

checkurl = (res, host, urlpath) ->
  fspath = resolve host, urlpath
  _fs.stat fspath, (err, info) ->
    if info?.isFile()
      jsOk res, path: fspath
    else if err?
      jsErr res, path: fspath, code: err.code, 404
    else
      jsErr res, path: fspath, code: 'EISDIR', 404

sendfile = (res, fspath) ->
  _fs.stat fspath, (err, info) ->
    unless info?.isFile()
      jsErr res, path: fspath, code: err.code, 404
    else
      res.writeHead 200, 'Content-Type': mime fspath
      _fs.createReadStream(fspath).pipe res

config = (res, req, url) ->
  host = url.pathname.split('/', 4)[3]

  if req.method is 'GET'
    unless host
      jsOk res, mounted
    else if mounted[host]
      jsOk res, mounted[host]
    else
      jsErr res, 'not found', 404

  else if req.method is 'DELETE'
    if mounted[host]
      unmount host
      jsOk res, 'deleted'
    else
      jsOk res, 'not found', 404

  else if req.method is 'PUT'
    req.on 'data', (data) ->
      req.body or= ''
      req.body += data

    req.on 'end', ->
      {docroot, urlroot} = _qs.parse req.body 

      unless docroot and urlroot
        jsErr res, 'docroot and urlroot required'
      else
        mount host, docroot, urlroot
        jsOk res, 'created', 201

mime = (path) ->
  table =
    'html': 'text/html'
    'htm':  'text/html'
    'css':  'text/css'
    'js':   'application/javascript'
    'json': 'application/javascript'
    'jpeg': 'image/jpeg'
    'jpg':  'image/jpeg'
    'png':  'image/png'
    'gif':  'image/gif'
  table[_path.extname(path).substring(1)] or 'data/binary'

emitter = (file) ->
  emitters[file] or= new _events.EventEmitter()

resolve = (host, pathname) ->
  host or= 'file:'

  unless mounted[host]
    return

  if host is 'file:'
    urlroot = '/'
    docroot = '/'
  else
    urlroot = mounted[host].urlroot
    docroot = mounted[host].docroot

  relative = _path.relative urlroot, pathname
  absolute = _path.join(docroot, relative)

  if relative.slice(0, 2) is '..'
    console.debug '  relative: %s', relative
    console.debug '  outsider: %s', absolute
  else
    console.debug '  relative: %s', relative
    console.debug '  absolute: %s', absolute

    absolute

subscribe = (socket) -> (data) ->
  socket.get 'id', (err, id) ->
    url    = _url.parse data.url
    fspath = resolve url.host, url.pathname

    unless fspath
      return console.log 'IGNORED %j', data

    console.log 'SUBSCRIBE %j', data

    emitter_ = emitter fspath
    listener =  -> socket.emit 'change', data
    emitter_.on 'change', listener

    sockets[id] or=
      emitters:  [],
      listeners: []

    sockets[id].emitters.push emitter_
    sockets[id].listeners.push listener

disconnect = (socket) -> (data) ->
  socket.get 'id', (err, id) ->
    return unless sockets[id]?

    for e in sockets[id].emitters
      for l in sockets[id].listeners
        e.removeListener 'change', l
    delete sockets[id]

connect = (socket) ->
  @id or= 0

  socket.set 'id', @id += 1, () ->
    socket.on 'subscribe', subscribe socket
    socket.on 'disconnect', disconnect socket
    socket.emit 'helo'

listener = new _fswatch.Listener (fspath, err, info) ->
  if info?.isDirectory()
    # Start watching new directory, watchTree will ignore us
    # if the directory is already being watched.
    listener.watchTree fspath

  unless err?
    emitter(fspath).emit 'change', fspath, err, info

mount = (host, docroot, urlroot = '/') ->
  docroot = _path.normalize docroot

  unmount host
  mounted[host] =
    host: host
    docroot: docroot
    urlroot: urlroot

  console.log 'MOUNTED %j', mounted[host]
  listener.watchTree docroot

unmount = (host) ->
  return unless mounted[host]?

  {docroot} = mounted[host]
  delete mounted[host]

  for k, entry of mounted when k isnt host
    # Some other site also has this docroot
    return if entry.docroot is docroot

  listener.unwatchTree docroot

start = (port) ->
  _app = _http.createServer(app port)
  _app.listen port

  sockets = _io.listen _app
  sockets.sockets.on 'connection', connect

  console.log "Ready on http://localhost:#{port}/ventricle"
  exports

exports = module.exports =
  start: start
  mount: mount
