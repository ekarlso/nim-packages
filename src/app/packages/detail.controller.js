'use strict';
/*jshint esnext: true */

class PackageDetailCtrl {
  constructor ($scope, $http, $stateParams) {
    $scope.params = $stateParams;
    $http.get('/packages/' + $stateParams.pkgId).success(function(result) {
        $scope.pkg = result;
    });
  }
}


PackageDetailCtrl.$inject = ['$scope', '$http', '$stateParams'];

export default PackageDetailCtrl;
