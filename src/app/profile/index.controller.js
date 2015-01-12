'use strict';
/*jshint esnext: true */

class ProfileCtrl {
  constructor ($scope, $http, $stateParams, $profile) {
    $profile.refresh();
    $scope.user = $profile.getUser();
  }
}


ProfileCtrl.$inject = ['$scope', '$http', '$stateParams', '$profile'];

export default ProfileCtrl;
