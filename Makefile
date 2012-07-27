all: test simple_open

clean:
	rm -f test simple_open

# test: inject hwpoison on filecache. In order to know the physical address
# of dirty pagecache, this program forks and child process mmap()s the target
# file. Roughly this program do the following:
#  - Parent process dirties a pagecache.
#  - Child process looks up the physical address of the pagecache and injects
#    hwpoison.
#  - Parent process accesses to the pagecache to check if error handling was
#    correctly done. Access type should be given by the caller.
test: test.c
	gcc -o $@ $<

test_truncate: test_truncate.c
	gcc -o $@ $<

# make alltest: runs all testcases. do_test.sh is a wrapper script
# using test.c program defined above. Basically they do the following:
#  - prepare a text file (assumed that it is filled with '0' in initial
#    state)
#  - test.c dirties the text file, injects hwpoison, accesses the target
#    page, and check if error handling works correctly.
#  - check that test.c worked expectedly by checking returned codes.
#
alltest: test1 test2 test_sticky test_trunc test_unpoison

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

# make test_sticky: check if the flag AS_HWPOISON is sticky after closing file.
test_sticky: test
	./do_test_sticky.sh ./test.txt 1

# make test_trunc: check if the flag AS_HWPOISON is clear when affected pages
# on the file was truncated out with truncate().
test_trunc: test_truncate
	./do_test_truncate.sh ./test.txt

# make test_unpoison: check if a false hwpoison can unpoisonable or not.
test_unpoison: test
	./do_test_unpoison.sh ./test.txt

test_multifiles: test
	./do_test_multifiles.sh

test_dropcache: test
	./do_test_dropcache.sh ./test.txt 1
