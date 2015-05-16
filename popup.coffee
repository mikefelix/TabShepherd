ts = new TabShepherd chrome, window.alert
popup = angular.module 'TabShepPopup', []

popup.controller 'PopupController', ($scope) ->
  ts.withCurrentWindow (win) ->
    $scope.test = 'yes'
    $scope.name = ts.getName(win) ? 'none'
    $scope.def = ts.getDefinition $scope.name if $scope.name
    $scope.def.patterns = [] if !$scope.def.patterns?
    console.dir($scope.def.patterns)

    $scope.setName = ->
      ts.withCurrentWindow (win) ->
        ts.setName win, $scope.name
        ts.storeDefinitions()

    $scope.addPattern = ->
      $scope.def.patterns.push $scope.newPattern
      ts.withCurrentWindow (win) ->
        ts.assignPattern $scope.newPattern, win
        $scope.newPattern = ''
        ts.storeDefinitions()

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