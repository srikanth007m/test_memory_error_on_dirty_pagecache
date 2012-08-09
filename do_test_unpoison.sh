#!/bin/bash

[ $# -ne 1 ] && \
    echo "Usage: `basename $BASH_SOURCE` file" \
    && exit 1

fail=0
testf=$1

ruby -e 'puts "0"*8192' > $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
echo "./test $testf 1 read onerror" > /dev/kmsg
page-types -b hwpoison -x -l > /dev/null
./test $testf 1 read onerror
page-types -b hwpoison -x -l > /dev/null
cat $testf > /dev/null
if [ $? -eq 0 ] ; then
    echo "PASS: unpoison succeeded."
else
    echo "FAIL: cat failed because hwpoison still remains."
    fail=$((fail+1))
fi

rm $testf

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
