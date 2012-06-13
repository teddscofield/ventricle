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

app = (port) -> (req, res) ->
  _util.debug _util.format('> http://%s%s', req.headers.host, req.url)

  # Parse the requested URL
  url = _url.parse 'http://' + req.headers.host + req.url, true
  cfg = /^\/ventricle($|\/.*$)/.exec url.pathname

  unless cfg
    # Not part of the configuration page
    path = resolve url.hostname, url.pathname
    return sendfile res, path

  resources = _path.join(__dirname, '..', '..', 'resources')
  path      = cfg[1]
  path      = '/index.html' if not path or path is '/'

  if /^\/sites/.test path
    config url, req, res
  else
    sendfile res, _path.join(resources, path)

sendfile = (res, path) ->
  _fs.stat path, (err, info) ->
    unless info?.isFile()
      res.writeHead 404, 'Not file'
      res.end 'Not file: ' + path
    else
      res.writeHead 200, {'Content-Type': mimeType(path)}
      _fs.createReadStream(path).pipe(res)

mimeType = (path) ->
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

config = (url, req, res) ->
  hostname = url.pathname.split('/', 4)[3]

  if req.method is 'GET'
    unless hostname
      res.writeHead 200, {'Content-Type': 'application/javascript'}
      res.end JSON.stringify(status: 'ok', message: mounted)
    else if mounted[hostname]
      res.writeHead 200, {'Content-Type': 'application/javascript'}
      res.end JSON.stringify(status: 'ok', message: mounted[hostname])
    else
      res.writeHead 404, {'Content-Type': 'application/javascript'}
      res.end JSON.stringify(status: 'error', message: 'not found')

  else if req.method is 'DELETE'
    if mounted[hostname]
      unmount hostname
      res.writeHead 200, {'Content-Type': 'application/javascript'}
      res.end JSON.stringify(status: 'ok', message: 'deleted')
    else
      res.writeHead 404, {'Content-Type': 'application/javascript'}
      res.end JSON.stringify(status: 'error', message: 'not found')

  else if req.method is 'PUT'
    req.on 'data', (data) ->
      req.body or= ''
      req.body += data

    req.on 'end', ->
      {docroot, urlroot} = _qs.parse req.body 

      unless docroot and urlroot
        res.writeHead 400, {'Content-Type': 'application/javascript'}
        res.end JSON.stringify(status: 'error', message: 'docroot and urlroot required')
      else
        mount hostname, docroot, urlroot
        res.writeHead 201, {'Content-Type': 'application/javascript'}
        res.end JSON.stringify(status: 'ok', message: 'created')

emitter = (file) ->
  emitters[file] or= new _events.EventEmitter()

resolve = (hostname, pathname) ->
  unless hostname
    # file://...
    urlroot = '/'
    docroot = '/'
  else if not mounted[hostname]
    return null

  urlroot = mounted[hostname]?.urlroot
  docroot = mounted[hostname]?.docroot

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
    listener = (path) -> socket.emit 'change', data
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

listener = new _fswatch.Listener (path, err, info) ->
  if info?.isDirectory()
    listener.watchTree path
  unless err?
    emitter(path).emit 'change', path, err, info

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
