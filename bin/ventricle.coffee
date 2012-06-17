#!/usr/bin/env node

_ventricle = require '../lib/ventricle'
_optimist  = require 'optimist'
_url       = require 'url'
_fs        = require 'fs'

argv       = _optimist.default(port: 4567).argv
server     = _ventricle.start argv.port

fail = (msg) ->
  console.error msg
  process.exit 1

for option in argv._
  # file:///absolute/asset/path
  # file://relative/asset/path
  #
  # http://hostname/urlpath?relative/asset/path
  # http://hostname/urlpath?/absolute/asset/path
  #
  # http://hostname:port/urlpath?relative/asset/path
  # http://hostname:port/urlpath?/absolute/asset/path
  url = _url.parse(option)

  if (url.protocol || 'file:') is 'file:'
    fail "nonsensical query string: #{option}" if url.query
    server.mount 'file:', url.pathname
  else
    docroot = url.query
    urlroot = url.pathname
    fail "missing ?/path/to/docroot: #{option}" unless docroot

    server.mount url.host, docroot, urlroot
