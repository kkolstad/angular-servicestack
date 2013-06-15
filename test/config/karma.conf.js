basePath = '..';

files = [
	'../node_modules/grunt-karma/node_modules/karma/adapter/jasmine.js',
	'../node_modules/grunt-karma/node_modules/karma/adapter/lib/jasmine.js',
	'lib/angular/angular.js',
	'lib/angular/angular-mocks.js',
	'unit-test.js',
	'angular-servicestack.js'
];

exclude = [];

reporters = ['progress'];

port = 8080;
runnerPort = 9100;
colors = true;
logLevel = LOG_INFO;
autoWatch = false;
browsers = ['Chrome'];
captureTimeout = 5000;
singleRun = false;