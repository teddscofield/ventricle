# Return the currently visible div.tab-content
activeTab = (tabContent = 'div.container > div.tab-content') ->
  $ '> div.tab-pane.active', tabContent

knownSites = []

createAlert = (parent, klass, message) ->
  parent = $ 'div.alerts', parent
  parent.append "<div class='alert #{klass}'><button type='button' class='close' data-dismiss='alert'>&times</button>#{message}</div>"

removeAlert = (parent, child) ->
  if child
    # Remove matching alerts
    $(child, parent).remove()
  else
    # Remove all alerts
    $(parent).empty()

createSite = (form) ->
  hostname = $('input[name=hostname]', form).val()
  urlroot  = $('input[name=urlroot]', form).val()
  docroot  = $('input[name=docroot]', form).val()

  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    loadSites()
    link = $ 'ul.nav a[href="#list"]'
    link.tab 'show'
    
    removeAlert '#list'
    createAlert '#list', 'alert-success', 'Successfully created <code>' + hostname + '</code>'

  $.ajax
    url: '/ventricle/sites/' + hostname
    type: 'PUT'
    data:
      urlroot: urlroot
      docroot: docroot
    cache: false
    error: onError
    success: onSuccess
    dataType: 'json'

deleteSite = (hostname) ->
  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    removeAlert '#list'
    createAlert '#list', 'alert-success', 'Successfully deleted <code>' + hostname + '</code>'
    loadSites()

  $.ajax
    url: '/ventricle/sites/' + hostname
    type: 'DELETE'
    cache: false
    error: onError
    success: onSuccess
    dataType: 'json'

checkDir = (fspath, tab) ->
  onError = (xhr, msg, text) ->
    data  = JSON.parse xhr.responseText
    removeAlert '#edit', '.doc-root-err'
    removeAlert '#edit', '.doc-root-ok'

    createAlert '#edit', 'alert-error doc-root-err', 'Document Root: ' + data.message.code

  onSuccess = (data, msg, xhr) ->
    message = data.message

    if (message.files?.length)
      message.files.sort()
      files  = message.files.slice(0, 8).join(', ')
      files += ', ...' if message.files.length > 8
    else
      files = 'empty directory'

    removeAlert '#edit', '.doc-root-err'
    removeAlert '#edit', '.doc-root-ok'
    createAlert '#edit', 'alert-info doc-root-ok', 'Document Root OK: ' + files

  if fspath
    # Clear alert 'Document Root is required'
    alert = $ '#edit div.alert.doc-root-req'
    alert.remove()

    $.ajax
      url:      '/ventricle/checkdir/' + fspath
      cache:    false
      error:    onError
      success:  onSuccess
      dataType: 'json'

loadSites = () ->
  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    sites = data.message
    tbody = []

    $('#list table.sites').hide()

    knownSites.length = 0

    for name, options of sites
      knownSites.push
        hostname: name
        urlroot: options.urlroot
        docroot: options.docroot

      tbody.push """
      <tr>
        <td>#{name}</td>
        <td>#{options.urlroot}</td>
        <td>#{options.docroot}</td>
        <td>
         <button class="btn btn-mini btn-info"><i class="icon-cog icon-white"></i> Edit</button>
         <button class="btn btn-mini btn-danger"><i class="icon-trash icon-white"></i> Remove</button>
        </td>
      </tr>
      """

    if tbody.length
      $('#list table.sites tbody').html(tbody.join '')
      $('#list table.sites').show()
    else
      $('#list table.sites').hide()
      createAlert '#list', 'alert-info', 'No sites have been configured. Click "New/Edit Site" to create one.'

  $.ajax
    url: '/ventricle/sites'
    cache: false
    error: onError
    success: onSuccess
    dataType: 'json'

initialize = () ->
  loadSites()

  inputs = $ 'input[name="docroot"]'
  inputs.bind 'blur', (e) ->
    checkDir e.srcElement.value, activeTab '#edit-http div.tab-content'

  # Bind submit button
  httpSubmit = $ '#btn-edit-http'
  httpSubmit.click (e) ->
    e.preventDefault()
    createSite '#edit-http'

  # Bind submit button
  fileSubmit = $ '#btn-edit-file'
  fileSubmit.click (e) ->
    e.preventDefault()
    createSite '#edit-file'

$ ->
  initialize()

window.configure =
  activeTab:  activeTab
  createSite: createSite
  deleteSite: deleteSite
  loadSites:  loadSites
  knownSites: knownSites
