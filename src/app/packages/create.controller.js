'use strict';
/*jshint esnext: true */

class CreatePackageCtrl {
  constructor ($scope, $state, $stateParams, $http) {
    $http.get('licenses').success(function(result) {
        $scope.licenses = result;
    });

    $scope.pkg = {
        maintainer: 'example@foo.io',
        tags: []
    };

    $http.get('tags').success(function(result) {
        $scope.tags = result;
    })

    $scope.submit = function() {
        $scope.pkg.license = $scope.license.name;
        $http.post('/packages', $scope.pkg).success(function() {
            $state.go('packages.list', $stateParams);
        });
    };
  }
}

CreatePackageCtrl.$inject = ['$scope', '$state', '$stateParams', '$http'];

export default CreatePackageCtrl;
