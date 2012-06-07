define (require, exports, module) ->
  _io       = require 'socket.io'
  _fs       = require 'fs'
  _url      = require 'url'
  _http     = require 'http'
  _util     = require 'util'
  _path     = require 'path'
  _events   = require 'events'
  _fswatch  = require 'ventricle/fswatch/kqueue'

  emitters = new Object
  sockets  = new Object
  mounted  = new Object

  # Send a script to inventory any <link> elements and then
  # ask ventricle for notices when those files change
  app = (port) -> (req, res) ->
    # Parse the requested URL
    url = _url.parse 'http://' + req.headers.host + req.url

    if url.pathname == '/ventricle.js'
      res.writeHead 200
      res.end bootstrap(url)
    else
      path = resolve url.hostname, url.pathname
      _fs.stat path, (err, info) ->
        unless info?.isFile()
          res.writeHead 404, 'Not file'
          res.end 'Not file: ' + path
        else
          res.writeHead 200, {'Content-Type': mimeType(path)}
          _fs.createReadStream(path).pipe(res)

  mimeType = (path) ->
    table =
      {'html': 'text/html'
      ,'htm':  'text/html'
      ,'css':  'text/css'
      ,'js':   'text/javascript'
      ,'jpeg': 'image/jpeg'
      ,'jpg':  'image/jpeg'
      ,'png':  'image/png'
      ,'gif':  'image/gif'}
    table[_path.extname(path).substring(1)] or 'data/binary'

  emitter = (file) ->
    emitters[file] or= new _events.EventEmitter()

  resolve = (hostname, pathname) ->
    unless mounted[hostname]?
      _util.debug _util.format('resolve %s %s = FAIL', hostname, pathname)
      return ""

    urlroot  = mounted[hostname].urlroot
    docroot  = mounted[hostname].docroot
    relative = _path.relative urlroot, pathname
    absolute = _path.join(docroot, relative)

    _util.debug _util.format('resolve %s %s = %j', hostname, pathname, absolute)
    absolute

  subscribe = (socket) -> (data) ->
    socket.get 'id', (err, id) ->
      _util.debug _util.format('SUBSCRIBE %j', data)
      url      = _url.parse(data.url)
      emitter_ = emitter resolve(url.hostname, url.pathname)
      listener = (path) -> socket.emit 'change', data
      emitter_.on 'change', listener

      sockets[id] or= {emitters: [], listeners: []}
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

    if hostname == 'file:'
      mounted[''] = {docroot: '/', urlroot: '/'}
    else
      mounted[hostname] = {docroot: docroot, urlroot: urlroot}

    listener.watchTree docroot

  start = (port) ->
    _app = _http.createServer(app port)
    _app.listen port
    sockets = _io.listen _app
    sockets.sockets.on 'connection', connect

  bootstrap = (url) ->
      ["// Load socket.io client"
      ,"var load = function(url, callback) {"
      ,"  var h = document.getElementsByTagName('head')[0]"
      ,"    , s = document.createElement('script');"
      ,""
      ,"  s.setAttribute('type', 'text/javascript');"
      ,"  s.setAttribute('src', url);"
      ,""
      ,"  s.onload = function() { if (callback) callback(url); };"
      ,"  s.onreadystatechange = function() {"
      ,"    if (callback && (s.readyState == 'loaded' || s.readyState == 'complete'))"
      ,"      callback(url); };"
      ,""
      ,"  h.appendChild(s);"
      ,"};"
      ,""
      ,"// Find assets and subscribe to events"
      ,"load('" + url.protocol + "//" + url.host + "/socket.io/socket.io.js', function() {"
      ,"  var styles = {};"
      ,"  var images = {};"
      ,"  var socket = io.connect('" + url.protocol + "//" + url.host + "/');"
      ,""
      ,"  socket.on('helo', function() {"
      ,"    window.jQuery"
      ,"      ? inventory(jQuery)"
      ,"      : load('http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js',"
      ,"          function() { inventory(jQuery); });"
      ,"  });"
      ,""
      ,"  socket.on('change', function(message) {"
      ,"    var a = document.createElement('a');"
      ,"        a.href   = message.url;"
      ,"        a.search = a.search.length"
      ,"          ? a.search + '&ventricle=' + Math.random()"
      ,"          : 'ventricle=' + Math.random();"
      ,""
      ,"    if (styles[message.url])"
      ,"      styles[message.url].href = a.href;"
      ,""
      ,"    if (images[message.url])"
      ,"      images[message.url].src = a.href;"
      ,"  });"
      ,""
      ,"  var resolveUrl = function(href) {"
      ,"    var a = $('<a href=' + href + '>...</a>');"
      ,"        return a[0].href;"
      ,"  };"
      ,""
      ,"  var inventory = function($) {"
      ,"    $(document).ready(function() {"
      ,"      $('link[rel=stylesheet]').each(function(n, e) {"
      ,"        styles[resolveUrl(e.href)] = e;"
      ,"        socket.emit('subscribe', {url: resolveUrl(e.href)});"
      ,"      });"
      ,"      $('img[src]').each(function(n, e) {"
      ,"        images[resolveUrl(e.src)] = e;"
      ,"        socket.emit('subscribe', {url: resolveUrl(e.src)});"
      ,"      });"
      ,"    });"
      ,"  };"
      ,"}); "].join("\n")

  exports.start       = start
  exports.mount       = mount
  exports
