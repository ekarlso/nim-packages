'use strict';
/*jshint esnext: true */

class LoginCtrl {
  constructor ($scope, $auth, $profile) {

    $scope.login = function() {
      $auth.login({ email: $scope.email, password: $scope.password })
        .then(function(response) {
          // Set profile data on initial login
          $profile.setUser(response.data.user);
        })
        .catch(function() {
        });
    };

    $scope.authenticate = function(provider) {
      $auth.authenticate(provider)
        .then(function(response) {
          // Set profile data on initial login
          $profile.setUser(response.data.user);
        })
        .catch(function() {
        });
    };

    //$scope.user = AccountService.user;
  }
}

LoginCtrl.$inject = ['$scope', '$auth', '$profile'];

export default LoginCtrl;
