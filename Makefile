all: test simple_open

test: test.c
	gcc -o $@ $< -lpginfo

alltest: test1 test2 test3

# checking if fsync fails expectedly after memory error on one page file
test1: test
	bash do_test1.sh ./test.txt 1

# checking if fsync fails after memory error on multi pages file
test2: test
	bash do_test1.sh ./text.txt 2

# checking if later open() for the file with AS_EHWPOISON set is blocked
test3: test simple_open
	bash do_test2.sh ./test.txt 2
