# Return the currently visible div.tab-content
activeTab = (tabContent = 'div.container > div.tab-content') ->
  $ '> div.tab-pane.active', tabContent

activateTab = (id) ->
  link = $ 'ul.nav a[href="' + id + '"]'
  link.tab 'show'

createAlert = (parent, klass, message) ->
  parent = $ 'div.alerts', parent
  parent.append "<div class='alert #{klass}'><button type='button' class='close' data-dismiss='alert'>&times</button>#{message}</div>"

removeAlert = (parent, child) ->
  if child
    # Remove matching alerts
    $(child, parent).remove()
  else
    # Remove all alerts
    $('div.alerts', parent).empty()

createSite = (form) ->
  host    = $('input[name="host"]',    form).val()
  urlroot = $('input[name="urlroot"]', form).val()
  docroot = $('input[name="docroot"]', form).val()

  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    listSites()
    activateTab '#list'
    removeAlert '#list'
    createAlert '#list', 'alert-success', 'Successfully created <code>' + host + '</code>'

  $.ajax
    url: '/ventricle/sites/' + host
    type: 'PUT'
    data:
      urlroot: urlroot
      docroot: docroot
    cache: false
    error: onError
    success: onSuccess
    dataType: 'json'

editSite = (options) ->
  if options.host == 'file:'
    selector  = '#edit-file'
    activateTab '#edit'
    activateTab '#edit-file'
  else
    selector  = '#edit-http'
    activateTab '#edit'
    activateTab '#edit-http'

  removeAlert '#edit'
  $('input[name="docroot"]', selector).val options.docroot
  $('input[name="urlroot"]', selector).val options.urlroot
  $('input[name="host"]',    selector).val options.host

removeSite = (options) ->
  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    removeAlert '#list'
    createAlert '#list', 'alert-success', 'Successfully deleted <code>' + options.host + '</code>'
    listSites()

  $.ajax
    url:      '/ventricle/sites/' + options.host
    type:     'DELETE'
    cache:    false
    error:    onError
    success:  onSuccess
    dataType: 'json'

viewSite = (options) ->
  if options.host == 'file:'
    window.open "file://#{options.docroot}"
  else
    window.open "http://#{options.host}#{options.urlroot}"

checkDir = (fspath, tab) ->
  onError = (xhr, msg, text) ->
    data  = JSON.parse xhr.responseText
    removeAlert '#edit', '.doc-root-err'
    createAlert '#edit', 'alert-error doc-root-err', 'Document Root: ' + data.message.code

  onSuccess = (data, msg, xhr) ->
    removeAlert '#edit', '.doc-root-err'

  unless fspath
    removeAlert '#edit', '.doc-root-err'
  else
    removeAlert '#edit', '.doc-root-req'

    $.ajax
      url:      '/ventricle/checkdir/' + fspath
      cache:    false
      error:    onError
      success:  onSuccess
      dataType: 'json'

readDir = (results) ->
  unless this.query[this.query.length - 1] is '/'
    return []

  onError = (xhr, msg, text) ->
    console.log xhr.responseText

  onSuccess = (data, msg, xhr) =>
    if data.message.path == '/'
      data.message.path = ''
    choices = data.message.dirs.sort()
    choices = (data.message.path + '/' + x for x in choices)

    results.length = 0
    results.push choices...

  $.ajax
    url:      '/ventricle/checkdir' + this.query
    cache:    false
    async:    false
    error:    onError
    success:  onSuccess
    dataType: 'json'

  results

listSites = () ->
  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    tbody = $('#list table.sites')
              .hide()
              .find('tbody')
              .empty()

    for name, options of data.message
      row = $ """
      <tr>
        <td>#{name}</td>
        <td>#{options.urlroot}</td>
        <td>#{options.docroot}</td>
        <td>
          <div class="btn-group">
            <button class="btn btn-mini"><i class="icon-globe icon-black"></i> View</button>
            <button class="btn btn-mini"><i class="icon-pencil icon-black"></i> Edit</button>
            <button class="btn btn-mini btn-danger"><i class="icon-trash icon-white"></i> Remove</button>
          </div>
        </td>
      </tr>
      """

      tbody.append row
      view   = $ 'button:eq(0)', row
      edit   = $ 'button:eq(1)', row
      remove = $ 'button:eq(2)', row

      view.click   ((options) -> (e) -> viewSite options) options
      edit.click   ((options) -> (e) -> editSite options) options
      remove.click ((options) -> (e) -> removeSite options) options

    if tbody.length
      $('#list table.sites').show()
    else
      createAlert '#list', 'alert-info', 'No sites have been configured. Click "New/Edit Site" to create one.'

  $.ajax
    url:      '/ventricle/sites'
    cache:    false
    error:    onError
    success:  onSuccess
    dataType: 'json'

initialize = () ->
  listSites()

  inputs = $ 'input[name="docroot"]'
  inputs.typeahead
    items:  20
    sorter: readDir

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
  removeSite: removeSite
  listSites:  listSites
