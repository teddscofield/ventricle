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

jsOk = (res, message, code = 200) ->
  res.writeHead code, {'Content-Type': mime 'response.js'}
  res.end JSON.stringify(status: 'ok', message: message)

jsErr = (res, message, code = 400) ->
  res.writeHead code, {'Content-Type': mime 'response.js'}
  res.end JSON.stringify(status: 'error', message: message)

app = (port) -> (req, res) ->
  _util.debug _util.format('> http://%s%s', req.headers.host, req.url)

  # Parse the requested URL
  url = _url.parse 'http://' + req.headers.host + req.url, true

  unless test = /^\/ventricle($|\/.*$)/.exec url.pathname
    # Not part of the configuration page
    fspath = resolve url.hostname, url.pathname
    return sendfile res, fspath

  # Dealing with config page from here down
  resources = _path.join(__dirname, '..', '..', 'resources')
  urlpath   = test[1]
  urlpath   = '/index.html' if not urlpath or urlpath is '/'

  if test = /^\/checkdir\/(.*)$/.exec urlpath
    checkdir res, _path.join('/' + test[1])

  else if test = /^\/checkurl\/([^./]+)(.*)$/.exec urlpath
    checkurl res, test[1], test[2]

  else if /^\/sites/.test urlpath
    config res, req, url

  else
    sendfile res, _path.join(resources, urlpath)

checkdir = (res, fspath) ->
  _fs.stat fspath, (err, info) ->
    if info?.isDirectory()
      jsOk res, path: fspath
    else if err?
      jsOk res, path: fspath, code: err.code
    else
      jsOk res, path: fspath, code: 'ENOTDIR'

checkurl = (res, host, urlpath) ->
  fspath = resolve host, urlpath
  _fs.stat fspath, (err, info) ->
    if info?.isFile()
      jsOk res, message: {path: fspath}
    else if err?
      jsErr res, 400, path: fspath, code: err.code
    else
      jsErr res, 400, path: fspath, code: 'EISDIR'

sendfile = (res, fspath) ->
  _fs.stat fspath, (err, info) ->
    unless info?.isFile()
      res.writeHead 404, 'Not file'
      res.end 'Not file: ' + fspath
    else
      res.writeHead 200, {'Content-Type': mime(fspath)}
      _fs.createReadStream(fspath).pipe(res)

config = (res, req, url) ->
  hostname = url.pathname.split('/', 4)[3]

  if req.method is 'GET'
    unless hostname
      jsOk res, mounted
    else if mounted[hostname]
      jsOk res, mounted[hostname]
    else
      jsErr res, 'not found', 404

  else if req.method is 'DELETE'
    if mounted[hostname]
      unmount hostname
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
        mount hostname, docroot, urlroot
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

resolve = (hostname, pathname) ->
  unless hostname
    # file://...
    urlroot = '/'
    docroot = '/'
  else if not mounted[hostname]
    return null

  urlroot = mounted[hostname].urlroot
  docroot = mounted[hostname].docroot

  relative = _path.relative urlroot, pathname
  absolute = _path.join(docroot, relative)
  _util.debug _util.format('relative: %s', relative)
  _util.debug _util.format('absolute: %s', absolute)

  absolute

subscribe = (socket) -> (data) ->
  socket.get 'id', (err, id) ->
    _util.debug _util.format('SUBSCRIBE %j', data)
    url      = _url.parse(data.url)
    emitter_ = emitter resolve(url.hostname, url.pathname)
    listener = (fspath) -> socket.emit 'change', data
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
    socket.emit 'helo', null

listener = new _fswatch.Listener (fspath, err, info) ->
  if info?.isDirectory()
    listener.watchTree fspath
  unless err?
    emitter(fspath).emit 'change', fspath, err, info

mount = (hostname, docroot, urlroot = '/') ->
  docroot = _path.resolve docroot

  unmount hostname
  mounted[hostname] =
    docroot: docroot
    urlroot: urlroot

  listener.watchTree docroot

unmount = (hostname) ->
  return unless mounted[hostname]?

  {docroot}   = mounted[hostname]
  delete mounted[hostname]

  for k, entry of mounted when k is not hostname
    return if entry.docroot is docroot

  listener.unwatchTree docroot

start = (port) ->
  _app = _http.createServer(app port)
  _app.listen port

  sockets = _io.listen _app
  sockets.sockets.on 'connection', connect
  exports

bootstrap = (url) ->
  _

exports = module.exports =
  start: start
  mount: mount
