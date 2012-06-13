# Return the currently visible div.tab-content
activeTab = (tabContent = 'div.container > div.tab-content') ->
  $ '> div.tab-pane.active', tabContent

knownSites = []

createAlert = (parent, klass, message) ->
  parent = $ parent
  parent.append "<div class='alert #{klass}'><button type='button' class='close' data-dismiss='alert'>&times</button>#{message}</div>"

clearAlerts = (parent) ->
  $(parent).empty()

createSite = (form) ->
  hostname = $('input[name=hostname]', form).val()
  urlroot  = $('input[name=urlroot]', form).val()
  docroot  = $('input[name=docroot]', form).val()

  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    link = $ 'ul.nav a[href="#list"]'
    link.tab 'show'
    
    clearAlerts '#list div.alerts'
    createAlert '#list div.alerts', 'alert-success', 'Successfully created <code>' + hostname + '</code>'
    loadSites()

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
    clearAlerts '#list div.alerts'
    createAlert '#list div.alerts', 'alert-success', 'Successfully deleted <code>' + hostname + '</code>'
    loadSites()

  $.ajax
    url: '/ventricle/sites/' + hostname
    type: 'DELETE'
    cache: false
    error: onError
    success: onSuccess
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
      createAlert '#list div.alerts', 'alert-info', 'No sites have been configured. Click "New/Edit Site" to create one.'

  $.ajax
    url: '/ventricle/sites'
    cache: false
    error: onError
    success: onSuccess
    dataType: 'json'

window.configure =
  activeTab:  activeTab
  createSite: createSite
  deleteSite: deleteSite
  loadSites:  loadSites
  knownSites: knownSites
