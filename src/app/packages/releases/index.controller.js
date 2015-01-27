'use strict';
/*jshint esnext: true */

class ReleaseCtrl {
  constructor ($scope, $http, $stateParams) {
    $scope.params = $stateParams;
    $http.get('/packages/' + $stateParams.pkgId).success(function(result) {
        $scope.pkg = result;
    });
  }
}


ReleaseCtrl.$inject = ['$scope', '$http', '$stateParams'];

export default ReleaseCtrl;
