all: test simple_open

# test: inject hwpoison on filecache. In order to know the physical address
# of dirty pagecache, this program forks and child process mmap()s the target
# file. Roughly this program do the following:
#  - Parent process dirty the pagecache.
#  - Child process lookup physical address and inject hwpoison
#  - Parent process does read/write/fsync to check if error handling was
#    correctly done.
test: test.c
	gcc -o $@ $< -lpginfo

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
test1: test
	bash do_test1.sh ./test.txt 1

# Load multiple pages of the file to pagecache.
test2: test
	bash do_test1.sh ./text.txt 2

# This testcase runs another process who opens the test file. We expect to
# confirm that clearing AS_HWPOISON is defered until all process opening the
# target file cloes it, and until then another open() is blocked.
test3: test simple_open
	bash do_test2.sh ./test.txt 2
