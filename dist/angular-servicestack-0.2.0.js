/**
 * @name: angular-servicestack
 * @description: A Service Stack client for AngularJS
 * @version: v0.2.0 - 2013-07-16
 * @link: https://github.com/kkolstad/angular-servicestack
 * @author: Kenneth Kolstad
 * @license: MIT License, http://www.opensource.org/licenses/MIT
 */
(function() {
  var module;

  module = angular.module('angular-servicestack', []);

  module.provider('serviceStackRestConfig', function() {
    var restConfig;
    restConfig = {
      urlPrefix: "",
      maxRetries: 3,
      maxDelayBetweenRetries: 4000,
      unauthorizedFn: null
    };
    return {
      setRestConfig: function(newConfig) {
        return angular.extend(restConfig, newConfig);
      },
      $get: function() {
        return restConfig;
      }
    };
  });

  module.factory('serviceStackRestClient', [
    'serviceStackRestConfig', '$http', '$q', '$timeout', '$location', '$log', function(serviceStackRestConfig, $http, $q, $timeout, $location, $log) {
      var RestClient, ServiceStackResponse;
      ServiceStackResponse = (function() {
        function ServiceStackResponse(response) {
          var _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
          this.response = response;
          this.success = (200 <= (_ref = this.response.status) && _ref < 300);
          this.statusCode = this.response.status;
          if (this.success) {
            this.data = this.response.data;
          }
          if (!this.success) {
            this.error = (_ref1 = this.response) != null ? (_ref2 = _ref1.data) != null ? _ref2.responseStatus : void 0 : void 0;
          }
          if (!this.success && ((_ref3 = this.response) != null ? (_ref4 = _ref3.data) != null ? (_ref5 = _ref4.responseStatus) != null ? (_ref6 = _ref5.errors) != null ? _ref6.length : void 0 : void 0 : void 0 : void 0) > 0) {
            this.validationErrors = (_ref7 = this.response) != null ? (_ref8 = _ref7.data) != null ? (_ref9 = _ref8.responseStatus) != null ? _ref9.errors : void 0 : void 0 : void 0;
          }
          if (this.isRetryable()) {
            this.incrementCollisionCount();
          }
          this.headers = this.response.headers;
          this.config = this.response.config;
        }

        ServiceStackResponse.prototype.collisionCount = function() {
          var _ref, _ref1, _ref2;
          return ((_ref = this.response) != null ? (_ref1 = _ref.config) != null ? (_ref2 = _ref1.data) != null ? _ref2._collisions : void 0 : void 0 : void 0) || 0;
        };

        ServiceStackResponse.prototype.getConfig = function() {
          return this.response.config;
        };

        ServiceStackResponse.prototype.hasValidationError = function() {
          var _ref;
          return ((_ref = this.validationErrors) != null ? _ref.length : void 0) > 0;
        };

        ServiceStackResponse.prototype.incrementCollisionCount = function() {
          var _ref, _ref1;
          this.response.config.data = ((_ref = this.response) != null ? (_ref1 = _ref.config) != null ? _ref1.data : void 0 : void 0) || {};
          return this.response.config.data._collisions = this.collisionCount() + 1;
        };

        ServiceStackResponse.prototype.isRetryable = function() {
          var _ref;
          return ((_ref = this.statusCode) === 500 || _ref === 503 ? true : void 0) && (this.collisionCount() <= serviceStackRestConfig.maxRetries);
        };

        ServiceStackResponse.prototype.isUnauthenticated = function() {
          return this.statusCode === 401;
        };

        ServiceStackResponse.prototype.isUnhandledError = function() {
          return !this.success && !this.isUnauthenticated() && !this.isRetryable();
        };

        ServiceStackResponse.prototype.toLog = function() {
          $log.log("ServiceStackResponse:");
          $log.log(this);
          $log.log("\thasValidationError: " + (this.hasValidationError()));
          $log.log("\tisUnhandledError:   " + (this.isUnhandledError()));
          $log.log("\tisUnauthenticated:  " + (this.isUnauthenticated()));
          $log.log("\tisRetryable:        " + (this.isRetryable()));
          return $log.log("\tcollisionCount:     " + (this.collisionCount()));
        };

        return ServiceStackResponse;

      })();
      RestClient = (function() {
        function RestClient() {}

        RestClient.prototype["delete"] = function(url, config) {
          if (config == null) {
            config = {};
          }
          config.method = "DELETE";
          config.url = url;
          return this.execute(config);
        };

        RestClient.prototype.get = function(url, config) {
          if (config == null) {
            config = {};
          }
          config.method = "GET";
          config.url = url;
          return this.execute(config);
        };

        RestClient.prototype.post = function(url, data, config) {
          if (data == null) {
            data = null;
          }
          if (config == null) {
            config = {};
          }
          config.method = "POST";
          config.data = data;
          config.url = url;
          return this.execute(config);
        };

        RestClient.prototype.put = function(url, data, config) {
          if (data == null) {
            data = null;
          }
          if (config == null) {
            config = {};
          }
          config.method = "PUT";
          config.data = data;
          config.url = url;
          return this.execute(config);
        };

        RestClient.prototype.fixUrl = function(url) {
          var prefix, result;
          if (0 === url.indexOf(serviceStackRestConfig.urlPrefix)) {
            return url;
          } else {
            $log.log("Fixing url: " + url);
            prefix = serviceStackRestConfig.urlPrefix.replace(/\/+$/, "");
            url = url.replace(/^\/+/, "");
            result = "" + prefix + "/" + url;
            $log.log("to url: " + prefix + "/" + url);
            return result;
          }
        };

        RestClient.prototype.execute = function(config) {
          var d, errorFn, me, promise, successFn, validationFn;
          me = this;
          successFn = [];
          errorFn = [];
          validationFn = [];
          config.url = this.fixUrl(config.url);
          d = $q.defer();
          promise = $http(config);
          promise.then(function(response) {
            var result;
            result = new ServiceStackResponse(response);
            return d.resolve(result);
          }, function(response) {
            var result;
            result = new ServiceStackResponse(response);
            return d.reject(result);
          });
          d.promise.success = function(fn) {
            successFn.push(fn);
            d.promise.then(function(response) {
              return fn(response, response.headers, response.config);
            });
            return d.promise;
          };
          d.promise.error = function(fn) {
            errorFn.push(fn);
            d.promise.then(null, function(response) {
              if (response.isUnhandledError() && !response.hasValidationError()) {
                return fn(response, response.headers, response.config);
              }
            });
            return d.promise;
          };
          d.promise.validation = function(fn) {
            validationFn.push(fn);
            d.promise.then(null, function(response) {
              if (response.isUnhandledError() && response.hasValidationError()) {
                return fn(response, response.headers, response.config);
              }
            });
            return d.promise;
          };
          d.promise.then(null, function(response) {
            if (response.isUnauthenticated()) {
              if ((serviceStackRestConfig.unauthorizedFn != null) && angular.isFunction(serviceStackRestConfig.unauthorizedFn)) {
                return serviceStackRestConfig.unauthorizedFn(response, $location);
              } else {
                if ((errorFn != null) && angular.isFunction(errorFn)) {
                  return errorFn(response);
                }
              }
            }
          });
          d.promise.then(null, function(response) {
            var sleepTime;
            if (response.isRetryable()) {
              sleepTime = Math.min(Math.random() * (Math.pow(4, response.collisionCount() - 1) * 100), serviceStackRestConfig.maxDelayBetweenRetries);
              return $timeout(function() {
                var fn, retryAttempt, _i, _j, _k, _len, _len1, _len2;
                retryAttempt = me.execute(response.getConfig());
                for (_i = 0, _len = successFn.length; _i < _len; _i++) {
                  fn = successFn[_i];
                  retryAttempt.success(fn);
                }
                for (_j = 0, _len1 = errorFn.length; _j < _len1; _j++) {
                  fn = errorFn[_j];
                  retryAttempt.error(fn);
                }
                for (_k = 0, _len2 = validationFn.length; _k < _len2; _k++) {
                  fn = validationFn[_k];
                  retryAttempt.validation(fn);
                }
                return retryAttempt;
              }, sleepTime);
            }
          });
          return d.promise;
        };

        return RestClient;

      })();
      return new RestClient();
    }
  ]);

}).call(this);
