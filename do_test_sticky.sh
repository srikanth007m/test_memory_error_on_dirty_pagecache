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
ls -li $testf
./test $testf $nrpages read onerror

grep ext4_inode /proc/slabinfo
cat $testf > /dev/null # should fail
if [ $? -eq 0 ] ; then
    echo "FAIL: error isolation does not work."
    fail=$((fail+1))
else
    echo "PASS: error isolation succeeded."
fi

page-types -b hwpoison -lN

# disturbing inode caches to remove inode of the target file
for i in `seq 1 1000` ; do echo 1 > ${tmpf}${i} ; done ; rm -f tmp.*
sync ; sync ; echo 3 > /proc/sys/vm/drop_caches

page-types -b hwpoison -lN

# retry checking AS_HWPOISON (expected not to be blocked)
grep ext4_inode /proc/slabinfo
cat $testf > /dev/null  # should succeed
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON was cleared in inode drop."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON is sticky."
fi

page-types -b hwpoison -x -lN
rm -f tmp.* $testf

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
