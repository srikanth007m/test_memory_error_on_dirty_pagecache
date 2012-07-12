#!/bin/bash

tmpf=`mktemp -p .`
fail=0

testf=$1
nrpages=$2

[ ! "$tmpf" ] && echo "tmpf is void. dangerous operation!" && exit 1
rm -f tmp.* $testf

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

# disturbing inode caches to remove inode of the target file
for i in `seq 1 10000` ; do echo 1 > ${tmpf}${i} ; done ; rm -f tmp.*
sync ; sync ; echo 3 > /proc/sys/vm/drop_caches

# retry checking AS_HWPOISON (expected not to be blocked)
grep ext4_inode /proc/slabinfo
cat $testf > /dev/null  # should succeed
if [ $? -eq 0 ] ; then
    echo "FAIL: AS_HWPOISON was cleared in inode drop."
    fail=$((fail+1))
else
    echo "PASS: AS_HWPOISON is sticky."
fi

rm -f tmp.* $testf
exit $fail