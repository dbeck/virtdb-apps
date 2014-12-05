#!/bin/sh
FILE=$1
PATHS="./ $*"

OK=0

if [ "X" = "X$FILE" ]
then
  echo "/no/file/given/to/filedir.sh"
else
  for i in $PATHS
  do
    FOUND=`find $i -maxdepth 4 -name "$FILE" -type f -exec ./abspath {} \; 2>/dev/null`
    if [ $? -eq 0 ]
    then
      for f in $FOUND
      do
        dirname $f
        OK=1
      done
    fi
  done
fi

if [ $OK -eq 0 ]
then
  echo "/file/not/found/$FILE"
fi

