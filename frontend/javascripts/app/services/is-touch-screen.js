(function () {
  'use strict';

  angular.module('ChaiBioTech.Common')
  .service('IsTouchScreen', [
    'WindowWrapper',
    '$window',
    function (WindowWrapper, $window) {
      return function IsTouchScreen() {
        var w = 800;
        var h = 600;
        var api_port = 4200;

        if(WindowWrapper.width() <= w && WindowWrapper.height() <= h) {
          var loc = $window.location;
          loc.assign(loc.protocol + '//' + loc.hostname + ':' + api_port);
        }
      };
    }
  ]);

}).call(window);
