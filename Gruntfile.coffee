'use strict';

lrSnippet = require('grunt-contrib-livereload/lib/utils').livereloadSnippet

mountFolder = (connect, dir) ->
	connect.static(require('path').resolve(dir))

module.exports = (grunt) ->

	# load all grunt tasks
	require('matchdep')
		.filterDev('grunt-*')
		.forEach(grunt.loadNpmTasks)

	# Project configuration.
	grunt.initConfig {
		pkg: grunt.file.readJSON('package.json'),

		# clean the dist folder before building
		clean: {
			test: {
				src: [".tmp"]
			},
			build: {
				src: ["dist"]
			}
		},

		# compile all the coffee script files into one file
		coffee: {
			test: {
				options: {
					sourceMap: true,
				},
				files: {
					'.tmp/unit-test.js': ['test/unit/**/*.coffee']  # compile and concat into single file
					'.tmp/angular-servicestack.js': ['src/**/*.coffee']  # compile and concat into single file
				}
			},
			build: {
				files: {
					'dist/angular-servicestack-<%= pkg.version %>.js': ['src/**/*.coffee']  # compile and concat into single file
				}
			}
		},

		concat: {
			options: {
				banner: '<%= meta.banner %>'
			},
			build: {
				files: {
					'dist/angular-servicestack-<%= pkg.version %>.js': ['dist/angular-servicestack-<%= pkg.version %>.js']
				}
			},
		},

  		# configure test server
		connect: {
			options: {
				port: 34543,
				hostname: 'localhost'
			},
			test: {
				options: {
					middleware: (connect) ->
						[
						  mountFolder(connect, '.tmp'),
						]
					}
			}
		},

		# copy files that don't need to be processed to the dist tree
		copy: {
			test: {
				files: [{
					expand: true, 
					cwd: 'test/', # change the current working directory to app, so all file are written to dist at the correct level
					src: [
						'config/**'#,  # copy all files in the config folder
						'lib/**'#,  # copy all files in the config folder
						#'lib/**'  # copy all files in the lib folder
					], 
					dest: '.tmp/'
				}]
			}
		},

		karma: {
			unit: {
				configFile: ".tmp/config/karma.conf.js",
				singleRun: true
			}
		},

		meta: {
			banner: '/**\n' +
				' * @name: <%= pkg.name %>\n' +
				' * @description: <%= pkg.description %>\n' +
				' * @version: v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>\n' +
				' * @link: <%= pkg.homepage %>\n' +
				' * @author: <%= pkg.author %>\n' +
				' * @license: MIT License, http://www.opensource.org/licenses/MIT\n' +
				' */\n'
		},

		# open the test server in a browser
		open: {
			server: {
				url: 'http://localhost:<%= connect.options.port %>'
			}
		},

		# uglify the js file after it has been complied by coffee
		uglify: {
			options: {
				banner: '<%= meta.banner %>',
				report: 'gzip',
				preserveComments: false
			}
			build: {
				src: 'dist/angular-servicestack-<%= pkg.version %>.js',
				dest: 'dist/angular-servicestack-<%= pkg.version %>-min.js'
			}
		},
	}

	grunt.registerTask 'build', [
		'clean:build'
		,'coffee:build'
		,'concat:build'
		,'uglify:build'
	]

	grunt.registerTask 'test', [
		'clean:test'
		,'copy:test'
		,'coffee:test'
		,'connect:test'
		,'karma:unit'
	]

	# Default task(s).
	grunt.registerTask 'default', ['build']
