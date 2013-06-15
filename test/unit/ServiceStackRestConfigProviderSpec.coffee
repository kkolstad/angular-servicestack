describe 'angular-servicestack > serviceStackRestConfig provider > ', () ->
 
	defaultConfig = {
		urlPrefix: "/api/",
		maxRetries: 3,
		maxWaitBetweenRetries: 4000,
		unauthorizedFn: (response) -> 
			return
	}

	customConfig = {
		urlPrefix: "/api/somethingelse",
		maxRetries: 45,
		maxWaitBetweenRetries: 9234
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
		expect(serviceStackRestConfig.maxWaitBetweenRetries).toEqual(defaultConfig.maxWaitBetweenRetries)
		# TODO: figure out how to make the next test work
		# expect(serviceStackRestConfig.unauthorizedFn).toBe(defaultConfig.unauthorizedFn)

	it 'should have provided config', () ->
		module (serviceStackRestConfigProvider) ->
			serviceStackRestConfigProvider.setRestConfig customConfig
			# module should not return anything, explicitly tell that to coffeescript
			return

		inject (serviceStackRestConfig) ->
			expect(serviceStackRestConfig.urlPrefix).toEqual(customConfig.urlPrefix)
			expect(serviceStackRestConfig.maxRetries).toEqual(customConfig.maxRetries)
			expect(serviceStackRestConfig.maxWaitBetweenRetries).toEqual(customConfig.maxWaitBetweenRetries)
			# TODO: figure out how to make the next test work
			# expect(serviceStackRestConfig.unauthorizedFn).toBe(customConfig.unauthorizedFn)
