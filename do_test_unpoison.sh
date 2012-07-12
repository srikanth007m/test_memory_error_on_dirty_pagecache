#!/bin/bash

[ $# -ne 1 ] && \
    echo "Usage: `basename $BASH_SOURCE` file" \
    && exit 1

fail=0
testf=$1

ruby -e 'puts "0"*8192' > $testf

echo "./test $testf 1 read onerror" > /dev/kmsg
page-types -b hwpoison -x -l
./test $testf 1 read onerror
page-types -b hwpoison -x -l
cat $testf > /dev/null
if [ $? -eq 0 ] ; then
    echo "PASS: unpoison succeeded."
else
    echo "FAIL: cat failed because hwpoison still remains."
    fail=$((fail+1))
fi

rm $testf
exit $fail
