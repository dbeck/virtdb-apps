var gulp = require('gulp');
var coffee = require('gulp-coffee');

gulp.task('coffee', function() {
    gulp.src('*.coffee')
        .pipe(coffee({bare: true}))
        .pipe(gulp.dest('./out/'))
});

gulp.task('watch', function()
{
    gulp.watch(['./*.coffee'], ['coffee']);
});

gulp.task('default', ['watch']);
