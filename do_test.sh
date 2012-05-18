#!/bin/bash

# Testing
#  - (increase dirty interval time.)
#  - prepare a text file (filled with 'a' in the initial state)
#  - user1 opens the file and read the first page (loading on pagecache)
#  - user2 opens and mmaps the file
#  - user2 continues to write the first page (keep pagecache dirty
#    by writing 1-9 randomly)
#  - user2 fills the first page with 'z' in the final state)
#  - user2 inject error on the first page
#  - user1 read the first page

testf="./test.txt"

echo "Prepare a text file"
echo "dd if=/dev/zero of=$tmpold bs=1024 count=8"
dd if=/dev/zero of=$testf bs=1024 count=8
echo -n "aaa" > $testf
sync
sync

echo "start testing" | tee /dev/kmsg

./user1 &
pid1=$!
./user2 &
pid2=$!

sleep 1
echo " --- wait 1 second --- "

echo "send signal to user1"
kill -s 10 $pid1
sleep 1
echo " --- wait 1 second --- "
echo "send signal to user2"
kill -s 10 $pid2
echo "send signal to user1"
kill -s 10 $pid1

sleep 1
echo " --- wait 1 second --- "

echo "send signal to user1"
kill -s 10 $pid1
echo "send signal to user2"
kill -s 10 $pid2
wait $pid1
wait $pid2
