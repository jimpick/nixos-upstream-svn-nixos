# Create an etc/event.d directory containing symlinks to the
# specified list of Upstart job files.
{runCommand, jobs}:

runCommand "upstart-jobs" {inherit jobs;}
  "
    ensureDir $out/etc/event.d
    for i in $jobs; do
      if test -d $i; then
        ln -s $i/etc/event.d/* $out/etc/event.d/
      fi
    done
  "
