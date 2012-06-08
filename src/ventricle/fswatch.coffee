exports = module.exports =
  if process.platform == 'linux'
    require './fswatch/inotify'
  else if process.platform == 'darwin'
    require './fswatch/kqueue'
  else if process.platform == 'win32'
    require './fswatch/windows'
  else
    require './fswatch/poll'
