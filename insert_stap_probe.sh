#!/bin/bash

tmpf=`mktemp`

# mce_rdmsrl mce_log
probes=( do_machine_check me_pagecache_clean send_sig_info invalidate_inode_page generic_error_remove_page __memory_failure )

probes_inline=( hwpoison_user_mappings )

cat <<EOF > ${tmpf}.stp
#!/usr/bin/stap

EOF

echo_stp() { echo "$@" >> ${tmpf}.stp; }

printbase='printf("%30s %10s %5d %3d %d:", probefunc(), execname(), pid(), cpu(), gettimeofday_us())'

for probe in ${probes[@]} ; do cat <<EOF >> ${tmpf}.stp
probe kernel.function("$probe") { $printbase ; printf("\n"); }
probe kernel.function("$probe").return { $printbase ; printf("ret\n"); }
EOF
done

for probe in ${probes_inline[@]} ; do cat <<EOF >> ${tmpf}.stp
probe kernel.function("$probe").inline { $printbase ; printf("\n"); }
EOF
done

cat <<EOF >> ${tmpf}.stp
probe kernel.function("__send_signal") {
    if (task_execname(\$t) == "filecopy") {
        $printbase ; printf("Send signal to filecopy\n");
    }
}
probe kernel.function("do_group_exit") {
    if (execname() == "filecopy") {
        $printbase ; printf("%d\n", \$exit_code);
        print_backtrace();
    }
}
probe kernel.function("get_signal_to_deliver") {
    if (execname() == "filecopy") {
        $printbase ; printf("%p\n", \$info);
    }
}
probe kernel.statement("get_signal_to_deliver@kernel/signal.c+10") {
    if (execname() == "filecopy") {
        $printbase ; printf("%x\n", \$signal->flags);
    }
}
probe kernel.function("me_pagecache_dirty") {
    $printbase ; printf("p %p, mapping %x\n", \$p, \$p->mapping);
}
probe kernel.statement("me_pagecache_dirty@mm/memory-failure.c+10") {
    $printbase ; printf("mapping %p\n", \$mapping);
}
EOF

cat ${tmpf}.stp
stap ${tmpf}.stp --vp 00001

rm -f ${tmpf}*
