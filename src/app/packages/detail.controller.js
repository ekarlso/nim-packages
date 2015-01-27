'use strict';
/*jshint esnext: true */

class PackageDetailCtrl {
  constructor ($scope, $http, $stateParams) {
    $http.get('/packages/' + $stateParams.pkgId).success(function(result) {
        $scope.pkg = result;
    });

    $http.get('/packages/' + $stateParams.pkgId + '/releases').success(function(result) {
        $scope.releases = result;
    })
  }
}


PackageDetailCtrl.$inject = ['$scope', '$http', '$stateParams'];

export default PackageDetailCtrl;
