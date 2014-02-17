module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-newer')

  grunt.initConfig
    coffee:
      client:
        expand: true,
        cwd: "coffee/client/"
        src: ["**/*.coffee"]
        dest: "static/js/"
        ext: ".js"
      shared:
        expand: true
        cwd: "coffee/shared/"
        src: ["**/*.coffee"]
        dest: "static/js-shared/"
        ext: ".js"

    watch:
      coffeescript:
        files: ["coffee/client/**/*.coffee", "coffee/shared/**/*.coffee"]
        tasks: ["newer:coffee"]
