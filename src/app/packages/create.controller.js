'use strict';
/*jshint esnext: true */

class CreatePackageCtrl {
  constructor ($scope, $state, $stateParams, $http) {
    $http.get('licenses').success(function(result) {
        $scope.licenses = result;
    });

    $scope.pkg = {
        maintainer: 'example@foo.io',
    };

    $scope.tags = [];
    $scope.getTags = function(query) {
        return $http.get('tags')
    }

    $scope.submit = function() {
        var pkg = $scope.pkg;
        pkg.tags = [];
        angular.forEach($scope.tags, function(v, i) {
            pkg.tags.push(v['text']);
        });

        $http.post('/packages', pkg).success(function() {
            $state.go('packages.list', $stateParams);
        });
    };
  }
}

CreatePackageCtrl.$inject = ['$scope', '$state', '$stateParams', '$http'];

export default CreatePackageCtrl;
