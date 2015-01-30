class TokenCtrl {
  constructor ($scope, $http, $stateParams, $profile) {
    // Token creation
    $scope.tokenFormOpen = false;
    $scope.tokenFormToggle = function() {
      $scope.tokenFormOpen = $scope.tokenFormOpen === false ? true : false;
    };

    $scope.minDate = new Date();
    $scope.expire = new Date();
    $scope.expire.setMilliseconds(0);
    $scope.expire.setSeconds(0);

    $scope.claims = {
      pkg: undefined,
      exp: undefined
    };

    $scope.setSeconds = function() {
      var exp = $scope.expire;
      exp.setMilliseconds(0)
      $scope.claims.exp = exp.getTime() / 1000;
    }

    $scope.loadingPackages = false;

    $scope.getPackages = function(val) {
      var user = $profile.getUser();
      $scope.loadingPackages = true;

      return $http.get('/packages?user_id=' + user.id).then(function(result) {
        $scope.loadingPackages = false;

        var packages = [];
        packages = ['foo', 'bar'];

        return packages;
      })
    }

    $scope.requestToken = function() {
      var req = {
        claims: $scope.claims
      };

      $http.post("/auth/tokens", claims).success(function(result) {
        $scope.token = result;
        $scope.createToken = false;
      })
    }
  }
}

TokenCtrl.$inject = ['$scope', '$http', '$stateParams', '$profile'];

export default TokenCtrl;
