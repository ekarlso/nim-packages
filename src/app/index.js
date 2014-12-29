'use strict';
/*jshint esnext: true */

import MainCtrl from './main/main.controller';
import PackageCtrl from './packages/packages.controller';
import CreatePackageCtrl from './packages/create.controller';
import PackageDetailCtrl from './packages/detail.controller';
import PackageVersionCtrl from './packages/version.controller';
import NavbarCtrl from '../components/navbar/navbar.controller';

angular.module('nimPackages', ['ngAnimate', 'ngCookies', 'ngTouch', 'ngSanitize', 'ngResource', 'ui.router', 'ui.bootstrap'])
  .controller('MainCtrl', MainCtrl)
  .controller('NavbarCtrl', NavbarCtrl)
  .controller('PackageCtrl', PackageCtrl)

  .config(function ($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('home', {
        url: '/',
        templateUrl: 'app/main/main.html',
        controller: 'MainCtrl'
      })
      .state('packages', {
        abstract: true,
        templateUrl: 'app/packages/index.html'
      })
      .state('packages.detail', {
        url: '/packages/:pkgId/detail',
        templateUrl: 'app/packages/detail.html',
        controller: PackageDetailCtrl
      })
      .state('packages.list', {
        url: '/packages',
        templateUrl: 'app/packages/list.html',
        controller: PackageCtrl
      })
      .state('packages.create', {
        url: '/packages/create',
        templateUrl: 'app/packages/create.html',
        controller: CreatePackageCtrl,
        view: 'packages'
      })
      .state('packages.version', {
        url: '/packages/:pkgId/:pkgVersion',
        templateUrl: 'app/packages/version.html',
        controller: PackageVersionCtrl
      });

    $urlRouterProvider.otherwise('/');
  })
;
