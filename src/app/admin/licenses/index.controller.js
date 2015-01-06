'use strict';
/*jshint esnext: true */

class LicenseIndexCtrl {
  constructor ($scope, $http) {
    $http.get('/licenses').success(function(result) {
        $scope.licenses = result;
    });

    $scope.selection = [];
    $scope.toggleSelection = function toggleSelection($index, license) {
        if ($scope.selection[$index] !== undefined) {
            $scope.selection.splice($index);
        } else {
            $scope.selection[$index] = license;
        }
    };

    $scope.deleteSelection = function() {
        angular.forEach($scope.selection, function(v, i) {
            $http.post('/licenses/' + v.name + '/delete').success(function() {
                $scope.licenses.splice(i, 1);
            });
        });
    };
  }
}


LicenseIndexCtrl.$inject = ['$scope', '$http'];

export default LicenseIndexCtrl;
