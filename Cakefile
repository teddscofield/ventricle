_fs     = require 'fs'
_path   = require 'path'
_util   = require 'util'
{spawn} = require 'child_process'

# Pop and return the last argument when it's a callback function
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

# Pop and return the last argument when it's an options hash
op = (args) ->
  if typeof args[args.length - 1] is 'object'
    args.pop()
  else
    new Object

# Execute a command in a child process
sh = (cmd, args...) ->
  callback = cb args
  options  = op args
  options.stdin  or= '/dev/null'
  options.stdout or= process.stdout
  options.stderr or= process.stderr

  if typeof options.stdin is 'string'
    options.stdin = _fs.createReadStream options.stdin

  if typeof options.stdout is 'string'
    _options = flags: 'w'

    # Append mode
    if options.stdout.slice(0, 2) is '+ '
      _options.flags = 'a+'
      options.stdout = options.stdout.substr 2

    options.stdout = _fs.createWriteStream options.stdout, _options

  if typeof options.stderr is 'string'
    _options = flags: 'w'

    # Append mode
    if options.stdout.slice(0, 2) is '+ '
      _options.flags = 'a+'
      options.stderr = options.stdout.substr 2

    options.stderr = _fs.createWriteStream options.stderr, _options

  console.log cmd, args...

  child = spawn cmd, args
  child.stdout.pipe options.stdout
  child.stderr.pipe options.stderr
  options.stdin.pipe child.stdin

  child.on 'exit', (code, signal) ->
    callback code, signal, cmd, args

# Then...
th = (f, args...) ->
  (code, signal, lastcmd, lastargs) ->
    if code is 0
      f args...
    else if signal?
      throw "err: #{lastcmd} was killed (#{signal})"
    else
      throw "err: #{lastcmd} exited with status #{code}"

# Used to override grammar precedence: parentheses always win
options = (x) -> x

###########################################################################

task 'compile', (k) ->
  sh     'coffee', '-c', '-o', 'resources/js', 'resources/coffee',
  th sh, 'coffee', '-c', '-o', 'lib', 'src',
  th sh, 'coffee', '-c', '-o', 'bin', 'bin',

  th sh, 'echo', '#!/usr/bin/env node', options(stdout: 'bin/ventricle'),
  th sh, 'cat',  'bin/ventricle.js',    options(stdout: '+ bin/ventricle'),
  th sh, 'rm',   'bin/ventricle.js',
  th sh, 'chmod', '+x', 'bin/ventricle', k

task 'clean', (k) ->
  sh 'echo', 'This page left intentionally blank, do not delete!', options(stdout: 'bin/ventricle'),
  th sh, 'rm', '-f', '-r', 'lib',
  th sh, 'rm', '-f', 'resources/js/subscribe.js',
  th sh, 'rm', '-f', 'resources/js/configure.js', k
