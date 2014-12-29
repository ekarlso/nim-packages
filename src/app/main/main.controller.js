'use strict';
/*jshint esnext: true */

class MainCtrl {
  constructor ($scope, $http) {
    $http.get('/packages').success(function(result) {
        $scope.packages = result;
    });
  }
}

MainCtrl.$inject = ['$scope', '$http'];

export default MainCtrl;
