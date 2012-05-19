all: test simple_open

clean:
	rm -f test simple_open

# test: inject hwpoison on filecache. In order to know the physical address
# of dirty pagecache, this program forks and child process mmap()s the target
# file. Roughly this program do the following:
#  - Parent process dirty the pagecache.
#  - Child process lookup physical address and inject hwpoison
#  - Parent process does read/write/fsync to check if error handling was
#    correctly done.
test: test.c
	gcc -o $@ $<

# make alltest: runs all testcases. do_testN.sh are wrapper scripts
# using test.c program defined above. Basically they do the following:
#  - prepare a text file (assumed that it is filled with '0' in initial
#    state)
#  - test.c dirty the text file, inject hwpoison and check read(), write()
#    fsync() works correctly after error handling.
#  - check it worked expectedly by checking returned codes of test.c
alltest: test1 test2 test3

# Load only one page of the file data into pagecache, this testcase check
# cornercase where fsync() doesn't check the mapping->flags to be fixed.
test1: test1a test1b test1c

test1a: test
	bash do_test1.sh ./test.txt 1 0
test1b: test
	bash do_test1.sh ./test.txt 1 1
test1c: test
	bash do_test1.sh ./test.txt 1 2

# Load multiple pages of the file to pagecache.
test2: test2a test2b test2c

test2a: test
	bash do_test1.sh ./text.txt 2 0
test2b: test
	bash do_test1.sh ./text.txt 2 1
test2c: test
	bash do_test1.sh ./text.txt 2 2

# This testcase runs another process who opens the test file. We expect to
# confirm that clearing AS_HWPOISON is defered until all process opening the
# target file cloes it, and until then another open() is blocked.
test3: test3a test3b test3c

test3a: test simple_open
	bash do_test2.sh ./test.txt 2 0
test3b: test simple_open
	bash do_test2.sh ./test.txt 2 1
test3c: test simple_open
	bash do_test2.sh ./test.txt 2 2
