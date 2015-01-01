#!/bin/sh
FILE=$1
PATHS="./ $*"

if [ "X" = "X$FILE" ]
then
  echo "/no/file/given/to/filedir.sh"
else
  for i in $PATHS
  do
    FOUND=`find $i -maxdepth 4 -name "$FILE" -type f -exec ./abspath {} \; 2>/dev/null | head -1`
    if [ $? -eq 0 ]
    then
      for f in $FOUND
      do
        dirname $f
        exit 0
      done
    fi
  done
fi

echo "/file/not/found/$FILE"
