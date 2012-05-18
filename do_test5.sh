#!/bin/bash

# Testing
#  - prepare a text file (written '0' in the initial state)
#  - fork
#  - parent process open the file and dirty it (write '1')
#  - child process open and mmap the file and inject hwpoison
#  - parent check the file content with read()

tmpf=`mktemp`
ret=0

[ $# -ne 2 ] && echo "Usage: `dirname $BASH_SOURCE` file nrpages" && exit 1

testf=$1
nrpages=$2

echo "Prepare a text file (echo -n \"0\" > $testf)"
for i in `seq 1 127` ; do
    echo -n "0000000000000000000000000000000000000000000000000000000000000000" >> $testf
done

echo "start testing" | tee /dev/kmsg

./simple_open $testf &
./simple_open $testf &
./simple_open $testf &
./simple_open $testf &
./simple_open $testf &
./simple_open $testf &
./simple_open $testf &
./simple_open $testf &

sleep 1

echo "./user5 $testf 1 ${nrpages}"
./user5 $testf 1 ${nrpages}

# echo "#####"
# lsof | grep test.txt
# echo "#####"

cat $testf > /dev/null
ret=$?

if [ $ret == 0 ] ; then
    # We expected user5 to exit with failure.
    echo "FAIL ($ret): new open() for AS_EHWPOISON file should be blocked."
    ret=1
else
    echo "PASS ($ret): new open() for AS_EHWPOISON file was blocked."
    ret=0
fi

pkill -f simple_open

rm -f $tmpf $testf

echo 3 > /proc/sys/vm/drop_caches

reset
exit $ret
