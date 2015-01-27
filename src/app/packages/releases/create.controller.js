'use strict';
/*jshint esnext: true */

class CreateReleaseCtrl {
  constructor ($scope, $state, $stateParams, $http) {
    $scope.release = {};

    $scope.methods = [
      'git',
      'http',
      'https'
    ]

    $scope.submit = function() {
      var release = $scope.release;

      $http.post('/packages/' + $stateParams.pkgId + '/releases', release).success(function() {
        $state.go('^');
      })
    }
  }
}

CreateReleaseCtrl.$inject = ['$scope', '$state', '$stateParams', '$http'];

export default CreateReleaseCtrl;
