#!/bin/sh

LHS=$1

if [ "X$LHS" = "X" ]
then
  echo "usage: file_exists.sh PATH"
  exit 100
fi

if [ -e $LHS ]
then
  echo 'true'
else
  echo 'false'
fi

exit 0
