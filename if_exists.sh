#!/bin/sh

LHS=$1
IFEXISTS=$2
IFNOT=$3

if [ "X$IFEXISTS" = "X" ]
then
  echo "usage: if_exists.sh PATH IFEXISTS"
  exit 100
fi

if [ -e $LHS ]
then
  echo $IFEXISTS
else
  echo $IFNOT
fi

exit 0
