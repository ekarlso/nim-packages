'use strict';
/*jshint esnext: true */

class TagsIndexCtrl {
  constructor ($scope, $http) {
    $http.get('/tags').success(function(result) {
        $scope.tags = result;
    });
  }
}


TagsIndexCtrl.$inject = ['$scope', '$http'];

export default TagsIndexCtrl;
