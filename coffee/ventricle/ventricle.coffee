_path = require 'path'

requirejs = require 'requirejs'
requirejs.config
  baseUrl: './js',
  nodeRequire: require

requirejs ['ventricle/server'], (ventricle) ->
  ventricle.start 8080
  ventricle.mount 'file:', 'example/htdocs'
