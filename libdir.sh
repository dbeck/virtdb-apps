#!/bin/sh
FILE=$1
PATHS="./ $*"
OK=0

if [ "X" = "X$FILE" ]
then
  echo "-L/no/file/given/to/filedir.sh"
else
  for i in $PATHS
  do
    CMD="find $i -maxdepth 4 -name \"$FILE\" -type f -exec ./abspath {} \;"
    FOUND=`find $i -maxdepth 4 -name "$FILE" -type f -exec ./abspath {} \; 2>/dev/null`
    RET=$?
    # echo "$CMD -> $RET"
    if [ $RET -eq 0 ]
    then
      for f in $FOUND
      do
        dn=`dirname $f`
        echo '-L'$dn
        OK=1
      done
    fi
  done
fi

if [ $OK -eq 0 ]
then
  echo "-L/file/not/found/$FILE"
fi
