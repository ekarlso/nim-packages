'use strict';
/*jshint esnext: true */

class CreateLicenseCtrl {
  constructor ($scope, $state, $stateParams, $http) {
    $scope.submit = function() {
        $http.post('/licenses', $scope.license).success(function() {
            $state.go('^', $stateParams);
        });
    };
  }
}

CreateLicenseCtrl.$inject = ['$scope', '$state', '$stateParams', '$http'];

export default CreateLicenseCtrl;
