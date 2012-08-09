#!/bin/bash

tmpf=`mktemp -p .`
fail=0

testf=$1

[ ! "$tmpf" ] && echo "tmpf is void. dangerous operation!" && exit 1
rm -f tmp.* $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 0 write" > /dev/kmsg
./test_truncate $testf 0 write
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON should still remain but was cleared."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON remains and write expectedly failed."
fi
rm -f $testf

sync

ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 1 write" > /dev/kmsg
./test_truncate $testf 1 write
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON should still remain but was cleared."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON remains and write expectedly failed."
fi
rm -f $testf

sync

ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 2 write" > /dev/kmsg
./test_truncate $testf 2 write
if [ $? -eq 0 ] ; then
    echo "PASS: AS_HWPOISON cleared after truncation."
else
    echo "FAIL: truncation did not clear AS_HWPOISON."
    fail=$((fail+1))
fi
rm -f $testf

sync

ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 0 read" > /dev/kmsg
./test_truncate $testf 0 read
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON should still remain but was cleared."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON remains and read expectedly failed."
fi
rm -f $testf

sync

ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 1 read" > /dev/kmsg
./test_truncate $testf 1 read
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON should still remain but was cleared."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON remains and read expectedly failed."
fi
rm -f $testf

sync

ruby -e 'puts "0"*4096*3' > $testf
echo "./test_truncate $testf 2 read" > /dev/kmsg
./test_truncate $testf 2 read
if [ $? -eq 0 ] ; then
    echo "PASS: AS_HWPOISON cleared after truncation."
else
    echo "FAIL: truncation did not clear AS_HWPOISON."
    fail=$((fail+1))
fi
rm -f $testf

rm -f tmp.* $testf
page-types -b hwpoison -x > /dev/null

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
