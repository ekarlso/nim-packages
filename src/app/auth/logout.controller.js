'use strict';
/*jshint esnext: true */

class LogoutCtrl {
  constructor ($auth, $state) {
    if (!$auth.isAuthenticated()) {
        $state.go('home');
    }

    $auth.logout().then(function() {
        $state.go('home');
    });
  }
}

LogoutCtrl.$inject = ['$auth', '$state'];

export default LogoutCtrl;
