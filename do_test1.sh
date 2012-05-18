#!/bin/bash

# Testing
#  - prepare a text file (written '0' in the initial state)
#  - fork
#  - parent process open the file and dirty it (write '1')
#  - child process open and mmap the file and inject hwpoison
#  - parent check the file content with read()

tmpf=`mktemp`
fail=0

[ $# -ne 2 ] && echo "Usage: `dirname $BASH_SOURCE` file nrpages" && exit 1

testf=$1
nrpages=$2

echo "Prepare a text file (filled with 0)"
ruby -e 'puts "0"*8192' > $testf

./test $testf 1 ${nrpages}
ret=$?
[ $ret -eq 0 ] && fail=$((fail + 1)) && \
    echo "FAIL ($ret): parent silently discarded the dirty pagecache" 

cat $testf > /dev/null
ret=$?
[ $ret -ne 0 ] && fail=$((fail + 1)) && \
    echo "FAIL ($ret): cat should succeed because AS_EHWPOISON should be cleared." 

[ $fail -eq 0 ] && echo "PASS: fsync failed expectedly and AS_HWPOISON was cleared when file was closed."

rm -f $tmpf $testf
exit $fail
