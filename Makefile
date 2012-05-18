all: filecopy user1 user2 user3 user4 user5 simple_open

user5: user5.c
	gcc -o $@ $< -lpginfo

test: test4 test5

test1: filecopy
	chown root:root *
	bash run-memory-error-writeback.sh

test2: user1 user2
	bash do_test.sh

# Obsolete
test3: user3 user4
	bash do_test2.sh

# checking if fsync fails expectedly after memory error on one page file
test4: user5
	bash do_test3.sh ./test.txt 1

# checking if fsync fails after memory error on multi pages file
test5: user5
	bash do_test3.sh ./text.txt 2

# checking if fsync fails after memory error on multi pages file on NFS
test6: user5
	bash do_test3.sh /media/test.txt 2

# checking if AS_EHWPOISON is cleared after closing error affected file
test7: user5
	bash do_test4.sh ./test.txt 2

# checking if later open() for the file with AS_EHWPOISON set is blocked
test8: user5 simple_open
	bash do_test5.sh ./test.txt 2

filecopy: filecopy.c
	gcc -o $@ $<

mce_probe.ko: mce_probe.stp
	@stap --vp 1 -m mce_probe -p 4 $<
