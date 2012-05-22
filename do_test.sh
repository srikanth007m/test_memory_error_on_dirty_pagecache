#!/bin/bash

# Testing
#  - prepare a text file (written '0' in the initial state)
#  - fork
#  - parent process open the file and dirty it (write '1')
#  - child process open and mmap the file and inject hwpoison
#  - parent check the file content with read()

tmpf=`mktemp`
fail=0

[ $# -ne 5 ] && \
    echo "Usage: `dirname $BASH_SOURCE` file nrpages expected accesstype onerror" \
    && exit 1

testf=$1
nrpages=$2
expected=$3
actype=$4
onerror=$5

# echo "Prepare a text file (filled with 0)"
ruby -e 'puts "0"*8192' > $testf

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

rm -f $tmpf $testf
# exit $fail
