'use strict';
/*jshint esnext: true */

class PackageVersionCtrl {
  constructor ($scope, $http, $stateParams) {
    $scope.params = $stateParams;
    $http.get('/packages/' + $stateParams.pkgId).success(function(result) {
        $scope.pkg = result;
    });
  }
}


PackageVersionCtrl.$inject = ['$scope', '$http', '$stateParams'];

export default PackageVersionCtrl;
