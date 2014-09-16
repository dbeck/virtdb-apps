var gulp = require('gulp');
var coffee = require('gulp-coffee');
var spawn = require('child_process').spawn;
var sourcemaps = require('gulp-sourcemaps');
var node;
var argv = require('minimist')(process.argv.slice(2));


/**
 * $ gulp server
 * description: launch the server. If there's a server already running, kill it.
 */
gulp.task('server', ['coffee'], function() {
  if (node) node.kill()
  node = spawn('node', ['out/csvDataSource.js', '--name='+argv['name'], '--url='+argv['url']], {stdio: 'inherit'})
  node.on('close', function (code) {
    if (code === 8) {
      console.log('Error detected, waiting for changes...');
      gulp.start('server');
    }
  });
  node.on('error', function () {
    console.log('Error detected, waiting for changes...');
    gulp.start('server');
  });
})

gulp.task('coffee', function() {
    gulp.src('*.coffee')
        .pipe(sourcemaps.init())
        .pipe(coffee({bare: true}))
        .pipe(sourcemaps.write('.'))
        .pipe(gulp.dest('./out'))
});

gulp.task('watch', ['coffee'], function()
{
    gulp.watch(['./*.coffee'], ['coffee']);
    gulp.watch(['out/csvDataSource.js'], function() {
        gulp.start('server')
    })
});

gulp.task('default', ['watch']);
