(function(url) {

  var JQUERY      = 'http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js'
    , SOCKET_IO   = url.protocol + '//' + url.host + '/socket.io/socket.io.js'
    , SOCKET_HOST = url.protocol + '//' + url.host + '/';

  // Load socket.io client
  var load = function(url, callback) {
    var h = document.getElementsByTagName('head')[0]
      , s = document.createElement('script');

    s.setAttribute('type', 'text/javascript');
    s.setAttribute('src', url);

    s.onload = function() { if (callback) callback(url); };
    s.onreadystatechange = function() {
      if (callback && (s.readyState == 'loaded' || s.readyState == 'complete'))
        callback(url); };

    h.appendChild(s);
  };

  // Find assets and subscribe to events
  load(SOCKET_IO, function() {
    var styles = {};
    var images = {};
    var socket = io.connect(SOCKET_HOST);

    socket.on('helo', function() {

      // Find stylesheets, scripts, images, and HTML
      var inventory = function($) {
        $(document).ready(function() {
          socket.emit('subscribe', {url: resolveUrl(window.location)});

          $('img[src]').each(function(_, e) {
            images[resolveUrl(e.src)] = e;
            socket.emit('subscribe', {url: resolveUrl(e.src)});
          });

          $('link[rel=stylesheet][href]').each(function(_, e) {
            styles[resolveUrl(e.href)] = e;
            socket.emit('subscribe', {url: resolveUrl(e.href)});
          });

          $('script[src]').each(function(_, e) {
            scripts[resolveUrl(e.href)] = e;
            socket.emit('subscribe', {url: resolveUrl(e.href)});
          });
        });
      };

      if (window.jQuery)
        inventory(jQuery);
      else
        load(JQUERY, function() { inventory(jQuery); });
    });

    socket.on('change', function(message) {
      var a = document.createElement('a');
          a.href    = message.url;
          a.search += '&ventricle=' + Math.random();

      if (styles[message.url])
        styles[message.url].href = a.href;

      if (images[message.url])
        images[message.url].src = a.href;

      if (scripts[message.url])
        window.location.reload(true); // todo

      if (window.location == message.url)
        window.location.reload(true); // todo
    });

    socket.on('reload', function(message) {
      window.location.reload(true);
    });

    socket.on('eval', function(message) {
    });

    // Convert relative a URL to an absolute URL
    var resolveUrl = function(href) {
      var a = $('<a href=' + href + '>...</a>');
          return a[0].href;
    };
  });

})
