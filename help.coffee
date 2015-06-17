ts = new TabShepherd chrome, window.alert
popup = angular.module 'TabShepPopup', []

popup.config ($locationProvider) ->
  $locationProvider.html5Mode true

popup.controller 'HelpController', ($scope, $location) ->
  par = $location.search().command
  cmd = ts.getCommand par
  if par
    $scope.command = par
    $scope.desc = cmd.desc
    $scope.examples = cmd.examples
