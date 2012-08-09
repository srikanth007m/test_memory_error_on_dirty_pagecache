#!/bin/bash

fail=0

testf=$1

[ $# -ne 1 ] && echo "Usage: `basename $BASH_SOURCE` filename" && exit 1
rm -f $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
sync ; sync
ruby -e 'puts "0"*8192' > $testf

cat $testf > /dev/null
./test_keepopen $testf &
pid=$!
./test $testf 1 read onerror

cat $testf > /dev/null
rm -f $testf

pkill -SIGUSR1 test_keepopen
wait $pid
ret=$?
if [ $ret -eq 1 ] ; then
    echo "PASS: access get EHWPOISON even if it's removed."
else
    echo "FAIL: access succeeded unexpectedly."
    fail=$[fail+1]
fi

file $testf > /dev/null

rm -f ${testf}*
page-types -b hwpoison -x -lN > /dev/null

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail+1]
fi

exit $fail
