'use strict';
/*jshint esnext: true */

class AccountService {
  constructor ($http, $auth) {
    this.user = null;

    this.getUser = function() {
        return this.user;
    };

    this.setUser = function(user) {
        this.user = user;
    };

    this.refresh = function() {
        var me = this;
        $http.get('/profile').success(function(result) {
            me.user = result;
        });
    };
  }
}


AccountService.$inject = ['$http'];

export default AccountService;
