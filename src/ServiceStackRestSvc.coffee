module = angular.module('angular-servicestack', [])

module.
	provider 'serviceStackRestConfig', () ->
		# default configuration
		restConfig = {
			urlPrefix: "",
			maxRetries: 3,
			maxDelayBetweenRetries: 4000,
			unauthorizedFn: null
		}

		setRestConfig: (newConfig) ->
			angular.extend restConfig, newConfig

		$get: () ->
			restConfig

# This module encapsulates all the functionality around making REST calls to the ServiceStack API
module.
	factory 'serviceStackRestClient', ['serviceStackRestConfig', '$http','$q', '$timeout', '$log', (serviceStackRestConfig, $http, $q, $timeout, $log) ->

		# @success = true if success, false if not
		# @statusCode = status code of the underlying REST request
		# @data = data returned by a successful REST request
		# @error = error returned by the REST request
		# @validationErrors = validation errors returned by the REST request
		class ServiceStackResponse
			constructor: (@response) ->
				# check if the method succeeded, anything between 200 and 299 (inclusive) is considered a success
				@success = 200 <= @response.status < 300
				# set the http status code. see http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
				@statusCode = @response.status
				@data = @response.data if @success
				@error = @response.data.responseStatus if not @success and @response? and @response.data?
				@validationErrors = @response.data.responseStatus.errors if not @success and @response? and @response.data? and @response.data.responseStatus? and @response.data.responseStatus.errors? and @response.data.responseStatus.errors.length > 0
				@incrementCollisionCount() if @isRetryable()

			# returns the collision count of the response. the collision count is stored in config.data of the request so that is can be passed to subsequent calls
			collisionCount: ->
				if @response.config? and @response.config.data?
					@response.config.data._collisions or 0
				else
					0

			# used when the request needs to be retried
			getConfig: ->
				@response.config

			# will return true if the service returned validation error(s)
			hasValidationError: ->
				@validationErrors? and @validationErrors.length > 0

			# should only be called internally
			incrementCollisionCount: () ->
				@response.config.data = @response.config.data or {}
				@response.config.data._collisions = @collisionCount() + 1

			# returns true if the request should be retried due to a recoverable server side error (500 - 599) and the maximum retry count has not been exceeded
			isRetryable: ->
				(yes if @statusCode in [ 500, 503 ]) and (@collisionCount() <= serviceStackRestConfig.maxRetries)

			# returns true if the request failed because the user was not authenticated
			isUnauthenticated: ->
				@statusCode is 401

			# this will be try if the error should be passed back. if false it should be handled by the ServiceStackRest
			isUnhandledError: ->
				not @success and not @isUnauthenticated() and not @isRetryable()

			# spits the response object out to the console
			toLog: ->
				$log.log "ServiceStackResponse:"
				$log.log @
				$log.log "\thasValidationError: #{ @hasValidationError() }"
				$log.log "\tisUnhandledError:   #{ @isUnhandledError() }"
				$log.log "\tisUnauthenticated:  #{ @isUnauthenticated() }"
				$log.log "\tisRetryable:        #{ @isRetryable() }"
				$log.log "\tcollisionCount:     #{ @collisionCount() }"

		class RestClient
			constructor: () ->

			# delete request shortcut
			delete: (url, config = {}) ->
				config.method = "DELETE"
				config.url = url
				@execute config

			# get request shortcut
			get: (url, config = {}) ->
				config.method = "GET"
				config.url = url
				@execute config

			# post request shortcut
			post: (url, data = null, config = {}) ->
				config.method = "POST"
				config.data = data
				config.url = url
				@execute config

			# put request shortcut
			put: (url, data = null, config = {}) ->
				config.method = "PUT"
				config.data = data
				config.url = url
				@execute config

			fixUrl: (url) ->
				if 0 is url.indexOf serviceStackRestConfig.urlPrefix
					url
				else
					$log.log "Fixing url: #{url}"
					prefix = serviceStackRestConfig.urlPrefix.replace(/\/+$/, "");
					url = url.replace(/^\/+/, "");
					result = "#{prefix}/#{url}"
					$log.log "to url: #{prefix}/#{url}"
					result

			# config is the same config that $http(config) expects: http://docs.angularjs.org/api/ng.$http
			execute: (config) ->

				me = @

				# create holders for callbacks so they can be passed on to retry attempts
				successFn = []
				errorFn = []
				validationFn =[]

				# prepend the api root if it isn't there already
				config.url = @fixUrl config.url

				# create a new deferred to return after this method completes
				d = $q.defer()

				# save the promise for the $http request so that it can be passed back for method chaining the callbacks
				promise = $http(config)

				# set up how the $http promise should be handled
				promise.then (response) ->
					# success, convert to an ServiceStackResponse and resolve
					result = new ServiceStackResponse(response)
					d.resolve result
				, (response) ->
					# failure, convert to an ServiceStackResponse and reject
					result = new ServiceStackResponse(response)
					d.reject result

				# this exposes the success callback
				d.promise.success = (fn) ->
					# store the callback in case we need to retry the request
					successFn.push(fn)
					d.promise.then (ServiceStackResponse) ->
						# execute success handler
						fn ServiceStackResponse
					# return the promise so that other callbacks can be chained
					d.promise

				# this exposes the error callback
				d.promise.error = (fn) ->
					# store the callback in case we need to retry the request
					errorFn.push(fn)
					d.promise.then null, (ServiceStackResponse) ->
						if ServiceStackResponse.isUnhandledError() and not ServiceStackResponse.hasValidationError()
							# execute error handler
							fn ServiceStackResponse
					# return the promise so that other callbacks can be chained
					d.promise

				# this exposes the validation callback
				d.promise.validation = (fn) ->
					# store the callback in case we need to retry the request
					validationFn.push(fn)
					d.promise.then null, (ServiceStackResponse) ->
						if ServiceStackResponse.isUnhandledError() and ServiceStackResponse.hasValidationError()
							# execute validation handler
							fn ServiceStackResponse
					# return the promise so that other callbacks can be chained
					d.promise

				# handle 401's
				d.promise.then null, (response) ->
					if response.isUnauthenticated()
						if serviceStackRestConfig.unauthorizedFn? and angular.isFunction serviceStackRestConfig.unauthorizedFn
							# execute the unauthorizedFn is one was supplied
							serviceStackRestConfig.unauthorizedFn() 
						else
							# if no unauthorizedFn was supplied, execute any registered error handlers
							errorFn response if errorFn? and angular.isFunction errorFn

				# handle 500 and 503 responses
				d.promise.then null, (response) ->
					if response.isRetryable()
						# handle retryable errors

						# calculate the amount of time to wait, before retrying
						sleepTime = Math.min (Math.random() * (Math.pow(4, response.collisionCount() - 1) * 100)), serviceStackRestConfig.maxDelayBetweenRetries

						#$log.log "500 error, retry #{response.collisionCount()} after waiting for #{sleepTime} ms"

						# retry the request using angular after the sleep time has passed, return the promise
						$timeout () ->
							# retry the request and attach the callbacks
							retryAttempt = me.execute(response.getConfig())

							# add any registered callbacks
							retryAttempt.success fn for fn in successFn
							retryAttempt.error fn for fn in errorFn
							retryAttempt.validation fn for fn in validationFn

							return retryAttempt

						,sleepTime	# wait for sleep time based on the exponential backoff calculation


				# return the promise
				d.promise

		# return the RestClient
		new RestClient()
	]