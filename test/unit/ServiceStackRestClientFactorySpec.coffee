describe "angular-servicestack > serviceStackRestClient factory > ", () ->

	# beforeEach module "angular-servicestack"
	$httpBackend = null
	ss = null
	ssConfig = null
	unauthorizedRequestCount = 0

	beforeEach(module 'angular-servicestack', ($provide, serviceStackRestConfigProvider) ->
		$provide.provider 'serviceStackRestConfig', serviceStackRestConfigProvider
		# serviceStackRestConfig to use for these tests
		restConfigForTheseTests = {
			urlPrefix: "/api/",
			maxRetries: 3,
			maxWaitBetweenRetries: 4000,	# 4 seconds
			unauthorizedFn: (response) ->
				unauthorizedRequestCount++
		}
		# inject the configuration for this test
		serviceStackRestConfigProvider.setRestConfig restConfigForTheseTests
		# module should not return anything, explicitly tell that to coffeescript
		return
	)
 
	beforeEach inject (serviceStackRestClient, serviceStackRestConfig) ->
		ss = serviceStackRestClient
		ssConfig = serviceStackRestConfig

	# helper function to mock the http request/response based on the above responses
	mockResponse = (r) ->
		$httpBackend.expectGET(r.url).respond () -> [r.code, r.data]

	describe "Successful REST Call", () ->

		response = {
			code: 200
			url: "/api/method/200"
			data: { id: 2}
		}

		beforeEach inject (_$httpBackend_) ->
			# setup $http mocks
			$httpBackend = _$httpBackend_;
			mockResponse response

		it "should fire success handler", () ->
			success = false
			error = false
			validation = false

			ss.get(response.url)
				.success (r) ->
					success = true
					expect(r.success).toBe(true)
					expect(r.statusCode).toEqual(response.code)
					expect(r.data).toEqual(response.data)
					expect(r.error).toBeUndefined()
					expect(r.validationErrors).toBeUndefined()
				.error (r) ->
					error = true
				.validation (r) ->
					validation = true

			$httpBackend.flush()

			expect(success).toBe(true)
			expect(error).toBe(false)
			expect(validation).toBe(false)

	describe "Non-repeatable, non-authentication related error (anything >= 400 except 401, 500 and 503)", () ->

		response = {
			code: 404
			url: "/api/method/404"
			data: {
				"responseStatus": {
					"errorCode":"PageNotFound",
					"message":"Page not found",
					"errors":[]
				}
			}
		}

		beforeEach inject (_$httpBackend_) ->
			# setup $http mocks
			$httpBackend = _$httpBackend_;
			mockResponse response

		it "should fire error handler", () ->
			success = false
			error = false
			validation = false

			ss.get(response.url)
				.success (r) ->
					success = true
				.error (r) ->
					error = true
					expect(r.success).toBe(false)
					expect(r.statusCode).toEqual(response.code)
					expect(r.data).toBeUndefined()
					expect(r.error).toEqual(response.data.responseStatus)
					expect(r.validationErrors).toBeUndefined()
				.validation (r) ->
					validation = true

			$httpBackend.flush()

			expect(success).toBe(false)
			expect(error).toBe(true)
			expect(validation).toBe(false)

	describe "Validation Error REST Call", () ->

		response = {
			code: 400
			url: "/api/method/400"
			data: {
				"responseStatus": {
					"errorCode":"NotEmpty",
					"message":"'Name' should not be empty.",
					"errors":[
						{
							"errorCode": "NotEmpty",
							"fieldName":"Name",
							"message": "'Name' should not be empty."
						},						
						{
							"errorCode": "NotNull",
							"fieldName":"Name",
							"message": "'Name' should not be null."
						}
					]
				}
			}
		}

		beforeEach inject (_$httpBackend_) ->
			# setup $http mocks
			$httpBackend = _$httpBackend_;
			mockResponse response

		it "should fire validation handler", () ->
			success = false
			error = false
			validation = false

			ss.get(response.url)
				.success (r) ->
					success = true
				.error (r) ->
					error = true
				.validation (r) ->
					validation = true
					expect(r.success).toBe(false)
					expect(r.statusCode).toEqual(response.code)
					expect(r.data).toBeUndefined()
					expect(r.error).toEqual(response.data.responseStatus)
					expect(r.validationErrors).toEqual(response.data.responseStatus.errors)

			$httpBackend.flush()

			expect(success).toBe(false)
			expect(error).toBe(false)
			expect(validation).toBe(true)

	describe "Unauthenticated REST Call", () ->

		response = {
			code: 401
			url: "/api/method/401"
			data: {
				"responseStatus": {
					"errorCode":"Unauthenticated",
					"message":"Unauthenticated",
					"errors":[]
				}
			}
		}

		beforeEach inject (_$httpBackend_) ->
			# setup $http mocks
			$httpBackend = _$httpBackend_;
			mockResponse response

		it "should redirect to sign in path and not fire and handlers", () ->

			success = false
			error = false
			validation = false

			# get the current location, before getting redirected to the sign in route
			unauthorizedRequestCountBeforeRequest = unauthorizedRequestCount

			ss.get(response.url)
				.success (r) ->
					success = true
				.error (r) ->
					error = true
				.validation (r) ->
					validation = true

			$httpBackend.flush()

			# verify that the unauthorizedFn was called
			expect(unauthorizedRequestCount).toEqual(unauthorizedRequestCountBeforeRequest + 1)

			# assert that none of the callbacks were fired
			expect(success).toBe(false)
			expect(error).toBe(false)
			expect(validation).toBe(false)

	describe "Retryable errors", () ->

		response = {
			code: 500
			url: "/api/method/500"
			data: {
				"responseStatus": {
					"errorCode":"InternalServerError",
					"message":"Internal server error",
					"errors":[]
				}
			}
		}

		$timeout = null

		beforeEach inject (_$httpBackend_, $injector) ->
			# store mock $http
			$httpBackend = _$httpBackend_
			# get $timeout so it can be flushed during tests
			$timeout = $injector.get '$timeout'

		it "should retry until max retries are exceeded, the fire error handler", () ->

			success = false
			error = false
			validation = false

			expect($timeout).toBeDefined()

			httpRequestCount = 0

			$httpBackend.whenGET(response.url).respond (method, url, data) ->
				httpRequestCount += 1
				[response.code, response.data]

			# should fail silently the first 3 times then return an error
			ss.get(response.url)
				.success (r) ->
					success = true
				.error (r) ->
					error = true
					expect(r.success).toBe(false)
					expect(r.statusCode).toEqual(response.code)
					expect(r.data).toBeUndefined()
					expect(r.error).toEqual(response.data.responseStatus)
					expect(r.validationErrors).toBeUndefined()
				.validation (r) ->
					validation = true

			failSilently = (num) ->
				# flush the timeout after the first request
				$timeout.flush() if num > 1
				$httpBackend.flush(1)
				# assert that the correct number of http calls have been made
				expect(httpRequestCount).toEqual(num)
				# assert that none of the callbacks were fired
				expect(success).toBe(false)
				expect(error).toBe(false)
				expect(validation).toBe(false)

			# run through all but the last request
			failSilently num for num in [1..ssConfig.maxRetries]

			# this is the last time it should fail and trigger the error callback
			$timeout.flush()
			$httpBackend.flush(1)

			# assert that the number of times the http request has been made is as expected
			expect(httpRequestCount).toEqual(ssConfig.maxRetries + 1)
			# assert that only the error callback was fired
			expect(success).toBe(false)
			expect(error).toBe(true)
			expect(validation).toBe(false)

	describe "Retryable errors followed by a success", () ->

		successResponse = {
			code: 200
			url: "/api/method/200"
			data: { id: 2}
		}

		retryResponse = {
			code: 500
			url: "/api/method/500"
			data: {
				"responseStatus": {
					"errorCode":"InternalServerError",
					"message":"Internal server error",
					"errors":[]
				}
			}
		}

		$timeout = null

		beforeEach inject (_$httpBackend_, $injector) ->
			# store mock $http
			$httpBackend = _$httpBackend_
			# get $timeout so it can be flushed during tests
			$timeout = $injector.get '$timeout'

		it "should retry until it succeeds, the fire success handler", () ->

			success = false
			error = false
			validation = false

			expect($timeout).toBeDefined()

			httpRequestCount = 0

			$httpBackend.whenGET(retryResponse.url).respond (method, url, data) ->
				# incremement the request count
				httpRequestCount += 1
				if httpRequestCount <= ssConfig.maxRetries
					# before the last attempt, return an error
					[retryResponse.code, retryResponse.data]
				else
					# once the max retries have been exceeded return a success, this will happen on the last attempt
					[successResponse.code, successResponse.data]

			# should fail silently the first 3 times then return an error
			ss.get(retryResponse.url)
				.success (r) ->
					success = true
					expect(r.success).toBe(true)
					expect(r.statusCode).toEqual(successResponse.code)
					expect(r.data).toEqual(successResponse.data)
					expect(r.error).toBeUndefined()
					expect(r.validationErrors).toBeUndefined()
				.error (r) ->
					error = true
				.validation (r) ->
					validation = true

			failSilently = (num) ->
				# flush the timeout after the first request
				$timeout.flush() if num > 1
				$httpBackend.flush(1)
				# assert that the correct number of http calls have been made
				expect(httpRequestCount).toEqual(num)
				# assert that none of the callbacks were fired
				expect(success).toBe(false)
				expect(error).toBe(false)
				expect(validation).toBe(false)

			# run through all but the last request
			failSilently num for num in [1..ssConfig.maxRetries]

			# this is the last pass, should succeed this time
			$timeout.flush()
			$httpBackend.flush(1)

			# assert that the number of times the http request has been made is as expected
			expect(httpRequestCount).toEqual(ssConfig.maxRetries + 1)
			# assert that only the error callback was fired
			expect(success).toBe(true)
			expect(error).toBe(false)
			expect(validation).toBe(false)
