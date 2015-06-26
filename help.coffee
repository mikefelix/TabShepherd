ts = new TabShepherd chrome, window.alert
popup = angular.module 'HelpPopup', []

popup.config ($locationProvider) ->
  $locationProvider.html5Mode
    enabled: true
    requireBase: false

popup.controller 'HelpController', ($scope, $location) ->
  $scope.categories =
    'Moving tabs': {}
    'Changing focus': {}
    'Managing window definitions': {}
    'Managing URL patterns': {}
    'Informational': {}
  for own name, cmd of ts.getCommands()
    $scope.categories[cmd.type][name] = cmd if $scope.categories[cmd.type]?
  $scope.selected = $location.search().command