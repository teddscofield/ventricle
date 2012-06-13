implementations =
  linux:   './fswatch/inotify'
  win32:   './fswatch/windows'
  darwin:  './fswatch/kqueue'
  solaris: './fswatch/eports'
  default: './fswatch/poll'

exports = module.exports =
  require implementations[process.platform] || implementations.default
