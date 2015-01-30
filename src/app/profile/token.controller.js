class TokenCtrl {
  constructor ($scope, $http, $stateParams, $profile) {
    $scope.minDate = new Date();

    $scope.tokens = [];

    $scope.init = function() {
      $scope.tokenFormOpen = false;
      $scope.expire = new Date();
      $scope.expire.setMilliseconds(0);
      $scope.expire.setSeconds(0);
      $scope.package = undefined;
    }

    $scope.init();

    $scope.tokenFormToggle = function() {
      $scope.tokenFormOpen = $scope.tokenFormOpen === false ? true : false;
    };

    $scope.getPackages = function(val) {
      var user = $profile.getUser();
      if (user === null) { return; }

      return $http.get('/packages?user_id=' + user.id).then(function(result) {
        return result.data;
      })
    }

    $scope.submit = function() {
      var expire = $scope.expire;
      expire.setMilliseconds(0);

      var claims = {
        exp: expire.getTime() / 1000
      };

      if ($scope.package !== undefined) {
        claims.pkg = $scope.package;
      }

      $http.post("/auth/tokens", {claims: claims}).success(function(result) {
        $scope.tokens.push(result);

        $scope.init()
      })
    }
  }
}

TokenCtrl.$inject = ['$scope', '$http', '$stateParams', '$profile'];

export default TokenCtrl;
