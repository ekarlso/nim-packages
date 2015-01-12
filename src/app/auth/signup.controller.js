'use strict';
/*jshint esnext: true */

class SignupCtrl {
  constructor ($scope, $auth) {
    $scope.signup = function() {
      $auth.signup({
        displayName: $scope.displayName,
        email: $scope.email,
        password: $scope.password
      });
    };
  }
}

SignupCtrl.$inject = ['$scope', '$auth'];

export default SignupCtrl;
