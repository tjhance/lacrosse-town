module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-newer');
  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-babel');

  grunt.initConfig({
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
      all: {
        options: {
          sourceMap: true,
          presets: ['flow', 'react', 'env'],
          plugins: ["transform-class-properties"],
        },
				files: [{
					expand: true,
					cwd: 'src/js',
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
      babel: {
        files: ["src/js/{client,shared,node,tests}/**/*.js"],
        tasks: ["newer:babel:all"],
      },
    },
  });
};
