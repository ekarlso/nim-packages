'use strict';
/*jshint esnext: true */

class TagsPackagesCtrl {
  constructor ($scope, $http, $stateParams) {
    $scope.$stateParams = $stateParams;
    $http.get('/packages?tag=' + $stateParams.tagName).success(function(result) {
        $scope.packages = result;
    });
  }
}


TagsPackagesCtrl.$inject = ['$scope', '$http', '$stateParams'];

export default TagsPackagesCtrl;
