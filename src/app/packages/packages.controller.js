'use strict';
/*jshint esnext: true */

class PackageCtrl {
  constructor ($scope, $http) {
    $http.get('/packages').success(function(result) {
        $scope.packages = result;
    });
  }
}


PackageCtrl.$inject = ['$scope', '$http'];

export default PackageCtrl;
