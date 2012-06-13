# Return the currently visible div.tab-content
activeTab = (tabContent = 'div.container > div.tab-content') ->
  $ '> div.tab-pane.active', tabContent

mkAlert = (parent, klass, message) ->
  parent = $ parent
  parent.append "<div class='alert #{klass}'><button type='button' class='close' data-dismiss='alert'>&times</button>#{message}</div>"

createSite = () ->

deleteSite = () ->

loadSites = () ->
  
  onError = (xhr, msg, text) ->
    console.log 'onError', xhr, msg, text

  onSuccess = (data, msg, xhr) ->
    sites = data.message
    tbody = []

    $('#list table.sites').hide()
    $('#list div.alerts').empty()

    for name, options of sites
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
      mkAlert '#list div.alerts', 'alert-info', 'No sites have been configured. Click "New/Edit Site" to create one.'

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
  mkAlert:    mkAlert
