module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-newer')
  grunt.loadNpmTasks('grunt-coffee-react')

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

    watch:
      options:
        atBegin: true
      coffeescript_client:
        files: ["src/coffee/client/**/*.coffee"]
        tasks: ["newer:cjsx:client"]
      coffeescript_shared:
        files: ["src/coffee/shared/**/*.coffee"]
        tasks: ["newer:coffee:shared"]
