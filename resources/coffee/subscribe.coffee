# Convert relative a URL to an absolute URL
resolveUrl = (href, component = 'href') ->
  a = $('<a href="' + href + '"></a>')[0]
  if component then a[component] else a

# Scripts loading scripts
load = (url, callback) ->
  h = document.getElementsByTagName('head')[0]
  s = document.createElement 'script'

  s.setAttribute 'type', 'text/javascript'
  s.setAttribute 'src', url

  s.onload = -> callback url if callback
  s.onreadystatechange = ->
    callback url if s?.readyState is 'loaded' or s?.readyState is 'complete'

  h.appendChild s

initialize = (url) ->
  SOCKET_IO   = url.protocol + '//' + url.host + '/socket.io/socket.io.js'
  SOCKET_HOST = url.protocol + '//' + url.host + '/'

  # Find assets and subscribe to events
  load SOCKET_IO, ->
    styles  = new Object
    images  = new Object
    scripts = new Object
    socket  = io.connect SOCKET_HOST

    socket.on 'reload', (message) ->
      window.location.reload true

    # Do someone else's homework
    socket.on 'eval', (message) ->
      console.log message

    # Something changed
    socket.on 'change', (message) ->
      a = document.createElement 'a'
      a.href    = message.url
      a.search += '&ventricle=' + Math.random()

      if styles[message.url]?
        styles[message.url].href = a.href

      if images[message.url]?
        images[message.url].src = a.href

      if scripts[message.url]?
        window.location.reload true

      if window.location.href is message.url
        window.location.reload true

    # Connection is alive
    socket.on 'helo', ->
      $ ->
        # HTML
        socket.emit 'subscribe', url: resolveUrl(window.location)

        # Images
        $('img[src]').each (_, e) ->
          images[resolveUrl e.src] = e
          socket.emit 'subscribe', url: resolveUrl e.src

        # Stylesheets
        $('link[rel=stylesheet][href]').each (_, e) ->
          styles[resolveUrl e.href] = e
          socket.emit 'subscribe', url: resolveUrl e.href

        # JavaScript
        $('script[src]').each (_, e) ->
          scripts[resolveUrl e.src] = e
          socket.emit 'subscribe', url: resolveUrl e.src

bootstrap = () ->
  # Use the script tag from which we were bjorn to learn our hostname
  for script in document.getElementsByTagName 'script'
    if '/ventricle/js/subscribe.js' is resolveUrl(script.src, 'pathname')
      initialize resolveUrl(script.src, false)

if window.jQuery?
  bootstrap jQuery
else
  load '/ventricle/js/jquery.min.js', -> bootstrap jQuery
