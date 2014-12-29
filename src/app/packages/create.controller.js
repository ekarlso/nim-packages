'use strict';
/*jshint esnext: true */

class CreatePackageCtrl {
  constructor ($scope, $state, $stateParams, $http) {
    $scope.pkg = {
        maintainer: 'example@foo.io',
        license: 'MIT'
    };

    $scope.submit = function() {
        $http.post('/packages', $scope.pkg).success(function(result) {
            $state.pkg = result;
            $state.go('packages.list', $stateParams);
        });
    };
  }
}

CreatePackageCtrl.$inject = ['$scope', '$state', '$stateParams', '$http'];

export default CreatePackageCtrl;
