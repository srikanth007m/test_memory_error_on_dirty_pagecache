#!/bin/bash

tmpf=`mktemp -p .`
fail=0

testf=$1

rm -f tmp.* $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
sync ; sync
ruby -e 'puts "0"*8192' > $testf
ln ${testf} ${testf}2
ln ${testf} ${testf}3
ln ${testf} ${testf}4

./test $testf 1 read onerror

cat $testf > /dev/null # should fail
if [ $? -eq 0 ] ; then
    echo "FAIL: error isolation does not work."
    fail=$((fail+1))
else
    echo "PASS: error isolation succeeded."
fi

rm -f ${testf}2

cat $testf > /dev/null # should fail
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON was cleared by drop one hard link."
    fail=$((fail+1))
else
    echo "PASS: error isolation succeeded."
fi

rm -f tmp.* ${testf}*
page-types -b hwpoison -x -lN

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
