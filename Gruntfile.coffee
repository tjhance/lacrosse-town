module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-newer')
  grunt.loadNpmTasks('grunt-coffee-react')
  grunt.loadNpmTasks('grunt-browserify')

  grunt.initConfig
    cjsx:
      client:
        expand: true,
        cwd: "src/coffee/client/"
        src: ["**/*.coffee"]
        dest: "src/static/js/"
        ext: ".js"

    coffee:
      shared:
        expand: true
        cwd: "src/coffee/shared/"
        src: ["**/*.coffee"]
        dest: "src/static/js-shared/"
        ext: ".js"

    browserify:
      client:
        #files:
        src: ["src/coffee/{client,shared}/**/*.coffee"]
        dest: "src/static/bundle.js"
        options:
          transform: ["cjsxify"]
          browserifyOptions:
            extensions: ['.coffee']

    watch:
      options:
        atBegin: true
      coffeescript_bundle:
        files: ["src/coffee/{client,shared}/**/*.coffee"]
        tasks: ["newer:browserify:client"]
