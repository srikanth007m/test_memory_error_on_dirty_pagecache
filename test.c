#define _GNU_SOURCE
#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/wait.h>

#include "mystd.h"
#include "mymman.h"
#include "mysem.h"
#include "pginfo.h"

#define REFADDR 0x700000000000

char rbuf[2*PS];
char wbuf[2*PS];
int debug = 0;

int main(int argc, char *argv[]) {
	int fd;
	int sem;
	int nrpages = 1;
	int ret = 0;
	int tmp = 0;
	int offset = 0;
	char c;
	char *filename;
	char *actype;
	char *onerror;
	char *p;
	pid_t pid;
	int wait_status;
	uint64_t pflag;
	struct sembuf sembuf;
	struct pagestat pgstat;

	if (argc != 5) {
		printf("Usage: %s filename nrpages accesstype onerror\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	filename = argv[1];
	nrpages = strtol(argv[2], NULL, 10);
	actype = argv[3];
	onerror = argv[4];
	DEB("filename = %s, nrpages = %d, actype = %s, onerror = %s\n",
	       filename, nrpages, actype, onerror);

	if (strcmp(onerror, "onerror") == 0)
		offset = 0;
	else
		offset = PS;

	sem = create_and_init_semaphore();

	fd = open_check(filename, O_RDWR, 0);
	tmp = pread(fd, rbuf, nrpages*PS, 0);
	DEB("parent first read %d [%c,%c]\n", tmp, rbuf[0], rbuf[PS]);

	get_semaphore(sem, &sembuf);
	if ((pid = fork()) == 0) {
		get_semaphore(sem, &sembuf); /* wait parent to dirty page */
		p = mmap_check((void *)REFADDR, nrpages * PS,
			       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
		if (p != (void *)REFADDR)
			err("mmap");
		if (nrpages == 1) {
			DEB("child read (after dirty) [%c]\n", p[0]);
#ifdef DEBUG
			get_pagestat(p, &pgstat);
#endif
		} else {
			DEB("child read (after dirty) [%c,%c]\n", p[0], p[PS]);
#ifdef DEBUG
			get_pagestat(p, &pgstat);
			get_pagestat(p+PS, &pgstat);
#endif
		}
		DEB("child hwpoison to vaddr %p\n", p);
		madvise(&p[0], PS, 100); /* hwpoison */
		put_semaphore(sem, &sembuf);
		get_semaphore(sem, &sembuf);
		DEB("child terminated\n");
		put_semaphore(sem, &sembuf);
		get_pflags(pgstat.pfn, &pflag, 1);
		exit(EXIT_SUCCESS);
	} else {
		DEB("parent dirty\n");
		usleep(1000);
		memset(wbuf, 49, nrpages * PS);
		pwrite(fd, wbuf, nrpages * PS, 0);
		tmp = pread(fd, rbuf, nrpages * PS, 0);
		DEB("parent second read (after dirty) %d [%c,%c]\n",
		       tmp, rbuf[0], rbuf[PS]);

		put_semaphore(sem, &sembuf); /* kick child to inject error */
		get_semaphore(sem, &sembuf); /* pagecache should be hwpoison */
		DEB("parent check\n");
		if (strcmp(actype, "read") == 0) {
			tmp = pread(fd, rbuf, PS, offset);
			if (tmp < 0)
				DEB("parent first read failed.\n");
			tmp = pread(fd, rbuf, PS, offset);
			DEB("parent read after hwpoison %d [%c,%c]\n",
			       tmp, rbuf[0], rbuf[PS]);
			if (tmp < 0) {
				ret = -1;
				perror("read");
			} else {
				ret = 0;
			}
		} else if (strcmp(actype, "writefull") == 0) {
			memset(wbuf, 50, nrpages * PS);
			tmp = pwrite(fd, wbuf, PS, offset);
			tmp = pwrite(fd, wbuf, PS, offset);
			DEB("parent write after hwpoison %d\n", tmp);
			if (tmp < 0) {
				ret = -1;
				perror("writefull");
			} else {
				ret = 0;
			}
		} else if (strcmp(actype, "writepart") == 0) {
			memset(wbuf, 50, nrpages * PS);
			tmp = pwrite(fd, wbuf, PS / 2, offset);
			tmp = pwrite(fd, wbuf, PS / 2, offset);
			DEB("parent write after hwpoison %d\n", tmp);
			if (tmp < 0) {
				ret = -1;
				perror("writefull");
			} else {
				ret = 0;
			}
		} else if (strcmp(actype, "fsync") == 0) {
			ret = fsync(fd);
			ret = fsync(fd);
			DEB("parent fsync after hwpoison [ret %d]\n", ret);
			if (ret)
				perror("fsync");
		} else if (strcmp(actype, "sync_range_write") == 0) {
			ret = sync_file_range(fd, offset, PS, SYNC_FILE_RANGE_WRITE);
			ret = sync_file_range(fd, offset, PS, SYNC_FILE_RANGE_WRITE);
			if (ret)
				perror("sync_range_write");
		} else if (strcmp(actype, "sync_range_wait") == 0) {
			ret = sync_file_range(fd, offset, PS, SYNC_FILE_RANGE_WAIT_BEFORE);
			ret = sync_file_range(fd, offset, PS, SYNC_FILE_RANGE_WAIT_BEFORE);
			if (ret)
				perror("sync_range_wait");
		} else if (strcmp(actype, "mmapread") == 0) {
			/*
			 * If mmap access failed, this program should be
			 * terminated by segmentation fault with non-zero
			 * returned value. So we don't set ret here.
			 */
			p = mmap_check((void *)REFADDR, nrpages * PS,
				       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
			if (p != (void *)REFADDR)
				err("mmap");
			c = p[offset];
			DEB("parent mmap() read after hwpoison [%c]\n", p[offset]);
		} else if (strcmp(actype, "mmapwrite") == 0) {
			p = mmap_check((void *)REFADDR, nrpages * PS,
				       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
			if (p != (void *)REFADDR)
				err("mmap");
			memset(&p[offset], 50, PS);
			DEB("parent mmap() write after hwpoison [%c]\n", p[offset]);
		}
	}
	put_semaphore(sem, &sembuf);

	waitpid(pid, &wait_status, 0);
	if (!WIFEXITED(wait_status))
		err("waitpid");

	delete_semaphore(sem);
	DEB("parent exit %d.\n", ret);
	return ret;
}
