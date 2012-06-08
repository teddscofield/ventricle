_path = require 'path'

requirejs = require 'requirejs'
requirejs.config
  baseUrl: './lib',
  nodeRequire: require

requirejs ['ventricle/server'], (ventricle) ->
  ventricle.start 8080
  ventricle.mount 'file:',     'example/htdocs'
  ventricle.mount 'macbook',   'example/htdocs'
  ventricle.mount 'localhost', 'example/htdocs'
