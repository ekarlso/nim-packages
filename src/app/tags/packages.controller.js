'use strict';
/*jshint esnext: true */

class TagsPackagesCtrl {
  constructor ($scope, $http) {
    $http.get('/tags').success(function(result) {
        $scope.tags = result;
    });
  }
}


TagsPackagesCtrl.$inject = ['$scope', '$http'];

export default TagsPackagesCtrl;
