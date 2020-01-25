module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-ts');
  grunt.loadNpmTasks('grunt-typescript');
  grunt.loadNpmTasks('grunt-browserify');

  grunt.initConfig({
		ts: {
      //client: {
      //  src: ["src/js/shared/**/*.ts", "src/js/client/**/*.tsx"],
      /*
        dest: "src/static/bundle.js",
				options: {
					module: 'amd',
					target: 'es5',
					sourceMap: true,
					declaration: true,

					noImplicitAny: true,
					strictNullChecks: true,
					noImplicitAny: true,
					noImplicitThis: true,
					noUnusedLocals: true,
 					jsx: "react",
 					moduleResolution: "node",
				}
      },*/

      all: {
        src: ["src/js/{node,client,shared,tests}/**/*.{ts,tsx}"],
        dest: "src/compiled/",
				options: {
					module: 'commonjs',
					target: 'es5',
					sourceMap: true,
					declaration: true,

					rootDir: 'src/js/',

					noImplicitAny: true,
					strictNullChecks: true,
					noImplicitAny: true,
					noImplicitThis: true,
					noUnusedLocals: true,

					lib: [ "es2016", "dom" ],

 					jsx: "react",
 					moduleResolution: "node",
				}
      },
    },

    browserify: {
      client: {
        src: ["src/compiled/{client,shared}/**/*.js"],
        dest: "src/static/bundle.js",
        options: {
          browserifyOptions: {
            extensions: ['.js'],
          },
          external: [ 'react', 'react-dom' ],
        },
      },
    },

    //babel: {
    //  all: {
    //    options: {
    //      sourceMap: true,
    //      presets: ['flow', 'react', 'env'],
    //      plugins: ["transform-class-properties"],
    //    },
		//		files: [{
		//			expand: true,
		//			cwd: 'src/js',
		//			src: ['**/*.js'],
		//			dest: 'src/compiled',
		//			ext: '.js',
		//		}],
    //  },
    //},

    //watch: {
    //  options: {
    //    atBegin: true,
    //  },
    //  babel: {
    //    files: ["src/js/{client,shared,node,tests}/**/*.js"],
    //    tasks: ["newer:babel:all", "newer:browserify:client"],
    //  },
    //},
  });
};
