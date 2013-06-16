Service Stack Client for AngularJS
==============

Makes consuming your Service Stack REST API much easier, by doing the following:

1. Exposes three event handlers success, error and validation. Only one is fired for each request. Success is pretty straight forward. Error is fired when any unhandled error is encountered. Validation is fired when Service Stack returns validation errors (https://github.com/ServiceStack/ServiceStack/wiki/Validation).
2. Service calls that return 401 call and unauthorized function that you provide when bootstrpping your AngularJS application. This can be used to automatically route the user to the login page and back after being authenticated.
3. Service calls that return 500 or 503 will be retried a certain number of times (defined in ServiceStackRestConfig)

##Assumptions
1. Errors return an object with a ResponseStatus property, if you throw (not return) HttpError this is done for you.

##Example Usage

####With angular-servicestack
```javascript
serviceStackRestClient.put("/api/customers", { id: 4, name: "customer" }).
	success(function(response) {
  	// do what you do
		result = response.data;
	}).
	error(function(response) {
		// handle non validation error
		errorCode = response.error.errorCode;
		message = response.error.message;
	}).
	validation(function(response) {
		// handle validation error
		errors = response.validationErrors;
	});
```

####Without angular-servicestack
```javascript
$http.put("/api/customers", { id: 4, name: "customer" }).
  success(function(data, status, headers, config) {
  	// do what you do
  	result = data;
  }).
  error(function(data, status, headers, config) {
  	if(status === 401) {
  		// handle redirecting to the login page
    } else if (status === 500 || status === 503) {
    	// retry the call and eventually handle too many failures
	  } else {
	  	if(data !== null && 
	  		data.responseStatus != null && 
	  		data.responseStatus.errors != null && 
	  		data.responseStatus.errors.length > 0)
	  		// handle validation error
	  		errors = data.responseStatus.errors;
	  	} else {
	  	// handle non validation error
	  		errorCode = data.responseStatus.errorCode;
	  		message = data.responseStatus.message;
		  }
		}
  }
});
```

##Configuration
In your AngularJS application add this code, customize for your application:
```javascript
angular.module('angular-servicestack').
	config(function(serviceStackRestConfigProvider) {
		serviceStackRestConfigProvider.setRestConfig {
			urlPrefix: "/api/",
			maxRetries: 3,
			maxDelayBetweenRetries: 4000,
			unauthorizedFn: function(response) { 
				continuePath = encodeURIComponent $location.path();
				$location.path "/a/signin/#{ continuePath }";
			}
		}
	});
```

### Options

#### urlPrefix
Type: `String`
Default: `""`

This string will be prepended to the url you supply to serviceStackRestClient if it doesn't already start with that string.

#####Example:

When `urlPrefix = "/api/"` and you call:
```js
serviceStackRestClient.put("/customers/search", {});
```
the url that the request will be sent to is: `/api/customers/search`

#### maxRetries
Type: `Number`
Default: `3`

Number of times that requests that return `500` or `503` HTTP status codes will be retired before failing and calling the `error` handler.

#### maxDelayBetweenRetries
Type: `Number`
Default: `4000`

Maximum number of milliseconds that will occur between retries.

#### unauthorizedFn
Type: `Function`
Default: `null`

This function will be executed when a `401` HTTP status code is return by a service call. If null, undefined or something other than a function any registered error handlers will be fired.

### Usage Examples


##Links
+ ServiceStack - http://servicestack.net/
+ AngularJS - http://angularjs.org/


##Building and Testing
####Node Installation Instructions
1.  Download and install nodejs @ nodejs.org
2.  Open a terminal and install grunt command line (may require sudo on OSX): npm install -g grunt-cli
3.  Clone the repo
4.  In a terminal/command prompt navigate to angular-servicestack/
5.  Execute: npm install


####To build
1. After following "Node Installation Instructions" above, in a terminal/command prompt navigate to angular-servicestack/
2. Execute: grunt


####To test
1. After following "Node Installation Instructions" above, in a terminal/command prompt navigate to angular-servicestack/
2. Execute: grunt test