module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-newer');
  grunt.loadNpmTasks('grunt-coffee-react');
  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-babel');

  grunt.initConfig({
    cjsx: {
      client: {
        expand: true,
        cwd: "src/coffee/client/",
        src: ["**/*.coffee"],
        dest: "src/static/js/",
        ext: ".js",
      },
    },

    coffee: {
      shared: {
        expand: true,
        cwd: "src/coffee/shared/",
        src: ["**/*.coffee"],
        dest: "src/static/js-shared/",
        ext: ".js",
      },
    },

    browserify: {
      client: {
        src: ["src/coffee/{client,shared}/**/*.coffee"],
        dest: "src/static/bundle.js",
        options: {
          transform: ["cjsxify"],
          browserifyOptions: {
            extensions: ['.coffee'],
          },
        },
      },
    },

    babel: {
      client: {
        options: {
          sourceMap: true,
          presets: ['flow', 'env'],
          plugins: ["transform-class-properties"],
        },
				files: [{
					expand: true,
					cwd: 'src/coffee',
					src: ['**/*.js'],
					dest: 'src/compiled',
					ext: '.js',
				}],
      },
    },

    watch: {
      options: {
        atBegin: true,
      },
      coffeescript_bundle: {
        files: ["src/coffee/{client,shared}/**/*.coffee"],
        tasks: ["newer:browserify:client"],
      },
      babel: {
        files: ["src/coffee/{client,shared}/**/*.js"],
        tasks: ["newer:babel:client"],
      },
    },
  });
};
