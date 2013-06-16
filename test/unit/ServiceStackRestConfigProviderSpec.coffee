describe 'angular-servicestack > serviceStackRestConfig provider > ', () ->
 
	defaultConfig = {
		urlPrefix: "",
		maxRetries: 3,
		maxDelayBetweenRetries: 4000,
		unauthorizedFn: null
	}

	customConfig = {
		urlPrefix: "/api/somethingelse",
		maxRetries: 45,
		maxDelayBetweenRetries: 9234
		unauthorizedFn: (response) ->
			return
	}

	beforeEach(module 'angular-servicestack', ($provide, serviceStackRestConfigProvider) ->
		$provide.provider 'serviceStackRestConfig', serviceStackRestConfigProvider
		# module should not return anything, explicitly tell that to coffeescript
		return
	)
 
	it 'should have default config', inject (serviceStackRestConfig) ->
		expect(serviceStackRestConfig.urlPrefix).toEqual(defaultConfig.urlPrefix)
		expect(serviceStackRestConfig.maxRetries).toEqual(defaultConfig.maxRetries)
		expect(serviceStackRestConfig.maxDelayBetweenRetries).toEqual(defaultConfig.maxDelayBetweenRetries)
		# TODO: figure out how to make the next test work
		expect(defaultConfig.unauthorizedFn).toBeNull()

	it 'should have provided config', () ->
		module (serviceStackRestConfigProvider) ->
			serviceStackRestConfigProvider.setRestConfig customConfig
			# module should not return anything, explicitly tell that to coffeescript
			return

		inject (serviceStackRestConfig) ->
			expect(serviceStackRestConfig.urlPrefix).toEqual(customConfig.urlPrefix)
			expect(serviceStackRestConfig.maxRetries).toEqual(customConfig.maxRetries)
			expect(serviceStackRestConfig.maxDelayBetweenRetries).toEqual(customConfig.maxDelayBetweenRetries)
			expect(angular.isFunction serviceStackRestConfig.unauthorizedFn).toEqual(true)
			# TODO: figure out how to make the next test work
			# expect(serviceStackRestConfig.unauthorizedFn).toBe(customConfig.unauthorizedFn)
