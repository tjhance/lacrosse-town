module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-newer')
  grunt.loadNpmTasks('grunt-coffee-react')

  grunt.initConfig
    cjsx:
      client:
        expand: true,
        cwd: "coffee/client/"
        src: ["**/*.coffee"]
        dest: "static/js/"
        ext: ".js"

    coffee:
      shared:
        expand: true
        cwd: "coffee/shared/"
        src: ["**/*.coffee"]
        dest: "static/js-shared/"
        ext: ".js"

    watch:
      options:
        atBegin: true
      coffeescript_client:
        files: ["coffee/client/**/*.coffee"]
        tasks: ["newer:cjsx:client"]
      coffeescript_shared:
        files: ["coffee/shared/**/*.coffee"]
        tasks: ["newer:coffee:shared"]
