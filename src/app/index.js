'use strict';
/*jshint esnext: true */

import MainCtrl from './main/main.controller';

import NavbarCtrl from '../components/navbar/navbar.controller';

import LoginCtrl from './auth/login.controller';
import LogoutCtrl from './auth/logout.controller';
import SignupCtrl from './auth/signup.controller';

import ProfileCtrl from './profile/index.controller';
import TokenCtrl from './profile/token.controller'

// Admin stuff
import CreateLicenseCtrl from './admin/licenses/create.controller';
import LicenseIndexCtrl from './admin/licenses/index.controller';

import TagsIndexCtrl from './tags/index.controller';
import TagsPackagesCtrl from './tags/packages.controller';

// Packages
import PackageCtrl from './packages/packages.controller';
import CreatePackageCtrl from './packages/create.controller';
import PackageDetailCtrl from './packages/detail.controller';

// Releases
import CreateReleaseCtrl from './packages/releases/create.controller';

import AccountService from './services/account';

angular.module('nimPackages', ['ui.router', 'ngSanitize', 'mgcrea.ngStrap', 'satellizer', 'ngTagsInput'])
  .controller('MainCtrl', MainCtrl)
  .controller('NavbarCtrl', NavbarCtrl)
  .service('$profile', AccountService)

  .config(function ($stateProvider, $urlRouterProvider, $authProvider) {
    $stateProvider
      .state('home', {
        url: '/',
        templateUrl: 'app/main/main.html',
        controller: 'MainCtrl'
      })

      .state('login', {
        url: '/login',
        templateUrl: 'app/auth/login.html',
        controller: LoginCtrl
      })
      .state('logout', {
        url: '/logout',
        template: null,
        controller: LogoutCtrl
      })
      .state('signup', {
        url: '/signup',
        templateUrl: 'app/auth/signup.html',
        controller: SignupCtrl
      })
      .state('profile', {
        url: '/profile',
        templateUrl: 'app/profile/index.html',
        controller: ProfileCtrl
      })
      .state('profile.tokens', {
        url: '/tokens',
        views: {
          "content": {
            templateUrl: 'app/profile/tokens.html',
            controller: TokenCtrl
          }
        }
      })

      .state('packages', {
        url: '/packages',
        abstract: true,
        templateUrl: 'app/packages/index.html'
      })
      .state('packages.create', {
        url: '/create',
        views: {
          '': {
            templateUrl: 'app/packages/create.html',
            controller: CreatePackageCtrl
          }
        }
      })
      .state('packages.list', {
        templateUrl: 'app/packages/list.html',
        controller: PackageCtrl
      })
      .state('packages.detail', {
        url: '/:pkgId/detail',
        views: {
          '': {
            controller: PackageDetailCtrl,
            templateUrl: 'app/packages/detail.html',
          }
        }
      })
      .state('packages.detail.releaseCreate', {
        url: '/release/create',
        views: {
          '@packages': {
            templateUrl: 'app/packages/releases/create.html',
            controller: CreateReleaseCtrl
          }
        }
      })

      .state('tags', {
        url: '/tags',
        templateUrl: 'app/tags/index.html',
        abstract: true
      })
      .state('tags.list', {
        url: '/list',
        views: {
          '': {
            templateUrl: 'app/tags/list.html',
            controller: TagsIndexCtrl
          }
        }
      })
      .state('tags.packages', {
        url: '/:tagName/packages',
        templateUrl: 'app/tags/packages.html',
        controller: TagsPackagesCtrl
      })

      .state('admin', {
        url: '/admin',
        templateUrl: 'app/admin/index.html',
        abstract: true
      })

      .state('admin.licenses', {
        url: '/licenses',
        templateUrl: 'app/admin/licenses/index.html',
        controller: LicenseIndexCtrl
      })
      .state('admin.licenses.create', {
        url: '/create',
        views: {
          '@admin': {
            controller: CreateLicenseCtrl,
            templateUrl: 'app/admin/licenses/create.html'
          }
        }
      });

    $urlRouterProvider.otherwise('/');

    $authProvider.github({
      clientId: '18aa6d30358a4d7a948e',
      redirectUri: 'https://nim-pkg.svcs.io'
    });
      //redirectUri: "https://npm-pkg.svcs.io:8080/index.html"});
  })
  .run(["$rootScope", "$state", function ($rootScope, $state) {
    $rootScope.$state = $state;
  }]);
