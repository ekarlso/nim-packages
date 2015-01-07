'use strict';
/*jshint esnext: true */

import MainCtrl from './main/main.controller';

import NavbarCtrl from '../components/navbar/navbar.controller';

// Admin stuff
import CreateLicenseCtrl from './admin/licenses/create.controller';
import LicenseIndexCtrl from './admin/licenses/index.controller';

import TagsIndexCtrl from './tags/index.controller';
import TagsPackagesCtrl from './tags/packages.controller';

// Packages
import PackageCtrl from './packages/packages.controller';
import CreatePackageCtrl from './packages/create.controller';
import PackageDetailCtrl from './packages/detail.controller';
import PackageVersionCtrl from './packages/version.controller';

angular.module('nimPackages', ['ui.router', 'ui.bootstrap'])
  .controller('MainCtrl', MainCtrl)
  .controller('NavbarCtrl', NavbarCtrl)

  .config(function ($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('home', {
        url: '/',
        templateUrl: 'app/main/main.html',
        controller: 'MainCtrl'
      })

      .state('packages', {
        url: '/packages',
        abstract: true,
        templateUrl: 'app/packages/index.html'
      })
      .state('packages.detail', {
        url: '/:pkgId/detail',
        templateUrl: 'app/packages/detail.html',
        controller: PackageDetailCtrl
      })
      .state('packages.list', {
        url: '/list',
        templateUrl: 'app/packages/list.html',
        controller: PackageCtrl
      })
      .state('packages.create', {
        url: '/packages/create',
        views: {
          '': {
            templateUrl: 'app/packages/create.html',
            controller: CreatePackageCtrl
          }
        }
      })
      .state('packages.version', {
        url: '/packages/:pkgId/:pkgVersion',
        templateUrl: 'app/packages/version.html',
        controller: PackageVersionCtrl
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
            templateUrl: '/app/tags/list.html',
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
  })
;
