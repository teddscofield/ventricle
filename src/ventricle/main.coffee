requirejs = require 'requirejs'
requirejs.config
  baseUrl: __dirname
  nodeRequire: require

requirejs ['server'], (ventricle) ->
  ventricle.start 8080
  ventricle.mount 'file:',     'example/htdocs'
  ventricle.mount 'macbook',   'example/htdocs'
  ventricle.mount 'localhost', 'example/htdocs'
