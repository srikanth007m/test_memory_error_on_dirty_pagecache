all: user5 simple_open

user5: user5.c
	gcc -o $@ $< -lpginfo

test: test4 test5

test1: filecopy
	chown root:root *
	bash run-memory-error-writeback.sh

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
