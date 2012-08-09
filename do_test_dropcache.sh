#!/bin/bash

tmpf=`mktemp -p .`
fail=0

testf=$1
nrpages=$2

[ ! "$tmpf" ] && echo "tmpf is void. dangerous operation!" && exit 1
rm -f tmp.* $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
sync ; sync
ruby -e 'puts "0"*8192' > $testf
./test $testf $nrpages read onerror

cat $testf > /dev/null # should fail
if [ $? -eq 0 ] ; then
    echo "FAIL: error isolation does not work."
    fail=$((fail+1))
else
    echo "PASS: error isolation succeeded."
fi

page-types -b hwpoison -lN > /dev/null

sync ; echo 3 > /proc/sys/vm/drop_caches

page-types -b hwpoison -lN > /dev/null

cat $testf > /dev/null  # should succeed

page-types -b hwpoison -x -lN > /dev/null
rm -f tmp.* $testf

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
