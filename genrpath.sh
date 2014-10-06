#!/bin/sh

for j in $*
do
  i=`echo $j | sed 's/-L//g'`
  if [ -d $i ]
  then
    echo "-Wl,-rpath=$i"
  fi
done

echo "-Wl,-rpath=/lib"

exit 0
