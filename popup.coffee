ts = new TabShepherd chrome, window.alert
popup = angular.module 'TabShepPopup', []

popup.controller 'PopupController', ($scope) ->
  $scope.init = (win) ->
    ts.withCurrentWindow (win) ->
      $scope.currentWindow = win
      $scope.name = ts.getName(win) ? ''
      if $scope.name
        $scope.def = ts.getDefinition $scope.name
        $scope.def.patterns = [] if $scope.def? and !$scope.def.patterns?
      ts.countWindowsAndTabs (info) ->
        $scope.winInfo = info
        vals = (v for k, v of info)
        $scope.totalTabs = vals.reduce(((mem, w) -> mem + w.tabs), 0)
        ts.withInactiveDefinitions (defs) ->
          $scope.inactiveDefs = defs
          $scope.$digest()

  $scope.runCommand = ->
    output = (msg) -> 
      $scope.output = msg
      $scope.$digest()
    ts.runCommand $scope.command, output if $scope.command

  $scope.setName = ->
    ts.withCurrentWindow (win) ->
      ts.setName win, $scope.name
      ts.storeDefinitions()
      $scope.init()

  $scope.addPattern = ->
    $scope.def.patterns.push $scope.newPattern
    ts.withCurrentWindow (win) ->
      ts.assignPattern win, $scope.newPattern
      $scope.newPattern = ''
      ts.storeDefinitions()
      $scope.init()

  $scope.goToWindow = (id) ->
    ts.withWindow id - 0, (win) ->
      $scope.currentWindow = win
      ts.focus win

  $scope.activateDef = (name) ->
    console.log 'Activate ' + name
    ts.activateDefinition name
    $scope.init()

  $scope.openDef = (name) ->
    console.log 'Activate ' + name
    ts.activateDefinition name
    $scope.init()

  $scope.removeDef = (name) ->
    console.log 'Remove ' + name
    ts.deleteDefinition name
    $scope.init()

  $scope.init()

#$ = (id) -> document.getElementById id
#
#showPatterns = (win) ->
#  def = ts.getDefinition win.name
#  $('patterns').innerHTML = ("<div>#{patt}</div>" for patt in def.patterns ? []).join('')
#
#ts.withCurrentWindow (win) ->
#  $('name').value = win.name ? ''
#  if win.name?
#    showPatterns win

#document.addEventListener 'DOMContentLoaded', ->
#  $('setName').addEventListener 'click', ->
#    ts.withCurrentWindow (win) ->
#      ts.setName win, $('name').value
#      ts.storeDefinitions()
#  $('addPattern').addEventListener 'click', ->
#    patt = $('newPattern').value
#    ts.withCurrentWindow (win) ->
#      ts.assignPattern patt, win
#      ts.storeDefinitions()
#      showPatterns win
