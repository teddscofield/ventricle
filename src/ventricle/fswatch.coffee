implementations =
  linux:   './fswatch/inotify'
  win32:   './fswatch/win32'
  darwin:  './fswatch/darwin'
  default: './fswatch/poll'

exports = module.exports =
  require implementations[process.platform] || implementations.default
