#!/bin/bash

tmpf=`mktemp`
fail=0

[ $# -ne 5 ] && \
    echo "Usage: `basename $BASH_SOURCE` file nrpages expected accesstype onerror

  file       : the name of target file
  nrpages    : # of pages to be loaded onto pagecache (1 or 2)
  expected   : whether this testcases should succeed or fail (\"success\" or \"fail\")
  accesstype : access type of parent's access after error injection.
               one of read/writefull/writepart/fsync/mmapread/mmapwrite
  onerror    : whether the parent's access after error injection is on
               error page or not. (\"onerror\" or \"offerror\")
" \
    && exit 1

testf=$1
nrpages=$2
expected=$3
actype=$4
onerror=$5

# echo "Prepare a text file (filled with 0)"
ruby -e 'puts "0"*8192' > $testf

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
echo "./test $testf $nrpages $actype $onerror" > /dev/kmsg
./test $testf $nrpages $actype $onerror
ret=$?
if [ $ret -eq 0 ] ; then
    if [ $expected = "succeed" ] ; then
        echo "PASS"
    else
        fail=$((fail + 1))
        echo "FAIL ($ret): parent access should fail, but succeeded." 
    fi
else
    if [ $expected = "succeed" ] ; then
        fail=$((fail + 1))
        echo "FAIL ($ret): parent access should succeed, but failed." 
    else
        echo "PASS"
    fi
fi

grep Corrupted /proc/meminfo
rm -f $tmpf $testf
page-types -b hwpoison -x -l
ipcs -s -t | cut -f1 -d' ' | egrep '[0-9]' | xargs ipcrm sem > /dev/null 2>&1
sync ; echo 3 > /proc/sys/vm/drop_caches

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
