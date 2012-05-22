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
alltest: test1 test2

# Load only one page of the file data into pagecache, this testcase check
# cornercase where fsync() doesn't check the mapping->flags to be fixed.
test1: test_1p_rd test_1p_wrf test_1p_wrp test_1p_fsf test_1p_mrd test_1p_mwr

test_1p_rd: test
	bash do_test.sh ./test.txt 1 fail    read       onerror
test_1p_wrf: test
	bash do_test.sh ./test.txt 1 succeed writefull  onerror
test_1p_wrp: test
	bash do_test.sh ./test.txt 1 fail    writepart  onerror
test_1p_fsf: test
	bash do_test.sh ./test.txt 1 fail    fsync      onerror
test_1p_mrd: test
	bash do_test.sh ./test.txt 1 fail    mmapread   onerror
test_1p_mwr: test
	bash do_test.sh ./test.txt 1 fail    mmapwrite  onerror

# Load multiple pages of the file to pagecache.
test2: test_2p_rd test_2p_wrf test_2p_wrp test_2p_fsf test_2p_mrd test_2p_mwr test_2p_rd_off test_2p_wrf_off test_2p_wrp_off test_2p_fsf_off test_2p_mrd_off test_2p_mwr_off

test_2p_rd: test
	bash do_test.sh ./test.txt 2 fail    read       onerror
test_2p_wrf: test
	bash do_test.sh ./test.txt 2 succeed writefull  onerror
test_2p_wrp: test
	bash do_test.sh ./test.txt 2 fail    writepart  onerror
test_2p_fsf: test
	bash do_test.sh ./test.txt 2 fail    fsync      onerror
test_2p_mrd: test
	bash do_test.sh ./test.txt 2 fail    mmapread   onerror
test_2p_mwr: test
	bash do_test.sh ./test.txt 2 fail    mmapwrite  onerror
test_2p_rd_off: test
	bash do_test.sh ./test.txt 2 succeed read       offerror
test_2p_wrf_off: test
	bash do_test.sh ./test.txt 2 succeed writefull  offerror
test_2p_wrp_off: test
	bash do_test.sh ./test.txt 2 succeed writepart  offerror
test_2p_fsf_off: test
	bash do_test.sh ./test.txt 2 succeed fsync      offerror
test_2p_mrd_off: test
	bash do_test.sh ./test.txt 2 succeed mmapread   offerror
test_2p_mwr_off: test
	bash do_test.sh ./test.txt 2 succeed mmapwrite  offerror
