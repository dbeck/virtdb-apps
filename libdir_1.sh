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
    RET=`echo $FOUND | grep -c "$FILE"`
    if [ $RET -gt 0 ] 
    then
      RET=0
      for f in $FOUND
      do
        if [ -r $f ]
        then
          RET=1
        fi
      done
    fi

    # try links too
    if [ $RET -eq 0 ]
    then
      CMD="find $i -maxdepth 4 -name \"$FILE\" -type l -exec ./abspath {} \;"
      FOUND=`find $i -maxdepth 4 -name "$FILE" -type l -exec ./abspath {} \; 2>/dev/null`
      RET=`echo $FOUND | grep -c "$FILE"`
      if [ $RET -gt 0 ] 
      then
        RET=0
        for f in $FOUND
        do
          if [ -r $f ]
          then
           RET=1
          fi 
        done
      fi
    fi

    # echo "$CMD -> $RET"
    if [ $RET -ne 0 ]
    then
      for f in $FOUND
      do
        dn=`dirname $f`
        echo '-L'$dn
        exit 0
      done
    fi
  done
fi

if [ $OK -eq 0 ]
then
  echo "-L/file/not/found/$FILE"
fi

