#!/bin/bash

# Testing
#  - prepare a text file (filled with 'a' in the initial state)
#  - user3 opens the file and read the first page (loading on pagecache)
#  - user4 opens and mmaps the file
#  - user3 continues to do read and write the first page (keep pagecache
#    dirty by writing 1-9 randomly)
#  - user4 injects error on the first page
#  - user3 read the first page ?

testf="./test.txt"

echo "Prepare a text file"
echo "dd if=/dev/zero of=$tmpold bs=1024 count=8"
dd if=/dev/zero of=$testf bs=1024 count=8
echo -n "0" > $testf
sync
sync

echo "start testing" | tee /dev/kmsg

./user3 &
pid3=$!
./user4 &
pid4=$!

sleep 1
echo " --- wait 1 second --- "
# echo "send signal to user3"
# kill -s 10 $pid3
# sleep 1
# echo " --- wait 1 second --- "
echo "send signal to user4"
kill -s 10 $pid4
echo "send signal to user3"
kill -s 10 $pid3

sleep 1
echo " --- wait 1 second --- "

echo "send signal to user3"
kill -s 10 $pid3
echo "send signal to user4"
kill -s 10 $pid4
wait $pid3
wait $pid4
