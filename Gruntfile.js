module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-newer');
  grunt.loadNpmTasks('grunt-coffee-react');
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
      babel: {
        files: ["src/coffee/{client,shared,node}/**/*.js"],
        tasks: ["newer:babel:all"],
      },
    },
  });
};
