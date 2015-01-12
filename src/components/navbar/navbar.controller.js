'use strict';
/*jshint esnext: true */

class NavbarCtrl {
  constructor ($scope, $profile, $auth) {
    $scope.date = new Date();

    $scope.$watch(
        function() {
            return $auth.isAuthenticated();
        },
        function(newVal) {
            if (!newVal) {
                return;
            }
            $scope.authed = newVal;
        }
    );

    $scope.$watch(
        function() {
            return $profile.getUser();
        },
        function(newVal) {
            if (!newVal) {
                return;
            }
            $scope.user = newVal;
        }
    );

    // If we are authenticated and no profile data is loaded get it so we show displayName etc.
    if ($auth.isAuthenticated() && $profile.getUser() === null) {
        $profile.refresh();
    }
  }
}

NavbarCtrl.$inject = ['$scope', '$profile', '$auth'];

export default NavbarCtrl;
