#!/bin/bash

fail=0

corrupted1=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`

filebase="./test.txt"
for i in `seq 1 1000` ; do
    for type in read writefull ; do
        testf=${filebase}${type}${i}
        ruby -e 'puts "0"*8192' > $testf
        ./test ${testf} 2 ${type} onerror > /dev/null
    done
done

for i in `seq 1 1000` ; do
    for type in read writefull ; do
        testf=${filebase}${type}${i}
        cat ${testf} > /dev/null 2>&1
        echo $?
        rm ${testf}
    done
done

page-types -b hwpoison -x

corrupted2=`grep -i corrupt /proc/meminfo | tr -s ' ' | cut -f2 -d' '`
if [ ! "$corrupted1" = "$corrupted2" ] ; then
    echo "FAIL: \"HardwareCorrupted:\" does not match between before/after testing ($corrupted1, $corrupted2)"
    fail=$[fail + 1]
fi

exit $fail
