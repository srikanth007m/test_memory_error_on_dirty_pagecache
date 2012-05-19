#!/bin/bash

# Testing
#  - prepare a text file (written '0' in the initial state)
#  - fork
#  - parent process open the file and dirty it (write '1')
#  - child process open and mmap the file and inject hwpoison
#  - parent check the file content with read()

tmpf=`mktemp`
fail=0

[ $# -ne 3 ] && echo "Usage: `dirname $BASH_SOURCE` file nrpages access" && exit 1

testf=$1
nrpages=$2
access=$3

echo "Prepare a text file (filled with 0)"
ruby -e 'puts "0"*8192' > $testf

./simple_open $testf &
./test $testf $access $nrpages
ret=$?
[ $ret -eq 0 ] && fail=$((fail + 1)) && \
    echo "FAIL ($ret): parent silently discarded the dirty pagecache" 

cat $testf > /dev/null
ret=$?
[ $ret -eq 0 ] && fail=$((fail + 1)) && \
    echo "FAIL ($ret): new open() for AS_HWPOISON file should be blocked."

pkill -f simple_open

cat $testf > /dev/null
ret=$?
[ $ret -ne 0 ] && fail=$((fail + 1)) && \
    echo "FAIL ($ret): cat failed because AS_HWPOISON remains after file close." 

[ $fail -eq 0 ] && echo "PASS: fsync failed expectedly and AS_HWPOISON was sticky until all users closed file."

rm -f $tmpf $testf
reset
exit $ret
