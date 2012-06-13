_fs     = require 'fs'
_path   = require 'path'
_util   = require 'util'
{spawn} = require 'child_process'

cb = (args) ->
  if typeof args[args.length - 1] is 'function'
    args.pop()
  else
    if typeof args[args.length - 1] is 'object'
      args.pop()

    (code, signal, lastcmd, lastargs) ->
      if signal?
        throw "err: #{lastcmd} was killed (#{signal})"
      else if code isnt 0
        throw "err: #{lastcmd} exited with status #{code}"

sh = (cmd, args...) ->
  callback = cb args
  console.log cmd, args...

  child = spawn cmd, args
  child.stdout.pipe process.stdout
  child.stderr.pipe process.stderr
  child.stdin.end()
  child.on 'exit', (code, signal) ->
    callback code, signal, cmd, args

th = (f, args...) ->
  (code, signal, lastcmd, lastargs) ->
    if code is 0
      f args...
    else if signal?
      throw "err: #{lastcmd} was killed (#{signal})"
    else
      throw "err: #{lastcmd} exited with status #{code}"

###########################################################################

task 'compile', (k) ->
  sh 'coffee', '-c', '-o', 'lib', 'src',
  th sh, 'coffee', '-c', '-o', 'resources/js', 'resources/coffee', k

task 'concat', (k) ->
  r = require 'requirejs'
  c = { baseUrl:  'lib/ventricle'
      , out:      'lib.js'
      , optimize: 'none'}
  r.optimize(c, console.log)

task 'build', (k) ->
  invoke 'compile',
  th invoke, 'concat'

task 'package', (k) ->
  console.log 'todo'

task 'install', (k) ->
  console.log 'todo'

