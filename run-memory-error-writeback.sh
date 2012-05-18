#!/bin/bash

# 2012/04/10: This test does not work because expect kills filecopy unexpectedly.

sdir=`dirname $BASH_SOURCE`
tmpf=`mktemp`
tmpold=${sdir}/tmp.old
tmpnew=${sdir}/tmp.new

# prepare
echo "dd if=/dev/zero of=$tmpold bs=1024 count=1024"
dd if=/dev/zero of=$tmpold bs=1024 count=1024
sync

original_dirty_bgratio=`cat /proc/sys/vm/dirty_background_ratio`
original_dirty_ratio=`cat /proc/sys/vm/dirty_ratio`
original_dirty_wbcsecs=`cat /proc/sys/vm/dirty_writeback_centisecs`
original_dirty_epcsecs=`cat /proc/sys/vm/dirty_expire_centisecs`

rm -f /tmp/tmp.page-types 2> /dev/null

cat <<EOF > ${tmpf}.inject
echo 0x\`cat \$1\` > /sys/kernel/debug/hwpoison/corrupt-pfn
EOF
chmod u+x ${tmpf}.inject

cat <<EOF > $tmpf
spawn ./filecopy

expect "Copied data from oldfile to newfile" {
    system "kill -s 10 [exp_pid]"
}

expect "mmap" {
    system "page-types -p [exp_pid] --raw -Nl -a 0x700000000+0x10000 | grep -v offset | grep 700001000 | cut -f2 > /tmp/tmp.page-types"
    system "kill -s 10 [exp_pid]"
}

expect "munmap" {
    system "echo kick hwpoison on pfn 0x[read [open "/tmp/tmp.page-types" r]]"
    system "bash ${tmpf}.inject /tmp/tmp.page-types"
    system "kill -s 10 [exp_pid]"
}

expect "fsync" {
    system "echo fsync"
    system "sync"
    system "kill -s 10 [exp_pid]"
}

expect "Finish successfully" {
    send "";
} eof {
    send "Exit unexpectedly";
    exit 1;
}
interact
EOF

# test body
expect $tmpf
echo $?

# cleanup
sudo rm -f $tmpold $tmpnew
rm -r ${tmpf}*
