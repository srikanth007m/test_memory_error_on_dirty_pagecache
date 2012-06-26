#define _GNU_SOURCE
/*
 * Usage: ./test filename flag nrpages
   ...
 * pages: nr of pages (only 1 or 2 are supported now.)
 */
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
#include <sys/stat.h>

#include "mystd.h"
#include "mymman.h"
#include "mysem.h"
#include "pginfo.h"

#define REFADDR 0x700000000000

char rbuf[3*PS];
char wbuf[3*PS];

int main(int argc, char *argv[]) {
	int fd;
	int sem;
	int nrpages = 3;
	int ret = 0;
	int tmp = 0;
	int offset = 0; /* page offset on which HWPOISON will be injected. */
	char *filename;
	char *actype;
	char *p;
	pid_t pid;
	int wait_status;
	uint64_t pflag;
	struct sembuf sembuf;
	struct pagestat pgstat;
	struct stat st;
	char buf[256];

	if (argc != 4) {
		printf("Usage: %s filename errorpage accesstype\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	filename = argv[1];
	offset = strtol(argv[2], NULL, 10) * PS; /* inject HWPOISON into the second page */
	actype = argv[3];

	printf("filename = %s, inject offset = %d, actype = %s\n",
	       filename, offset, actype);

	sem = create_and_init_semaphore();

	fd = open_check(filename, O_RDWR, 0);
	tmp = pread(fd, rbuf, nrpages*PS, 0);
	printf("parent first read %d [%c,%c,%c]\n",
	       tmp, rbuf[0], rbuf[PS], rbuf[2*PS]);

	get_semaphore(sem, &sembuf);
	if ((pid = fork()) == 0) {
		get_semaphore(sem, &sembuf); /* wait parent to dirty page */
		p = mmap_check((void *)REFADDR, nrpages * PS,
			       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
		if (p != (void *)REFADDR)
			err("mmap");
		printf("child read (after dirty) [%c,%c,%c]\n", p[0], p[PS], p[2*PS]);
		get_pagestat(p, &pgstat);
		get_pagestat(p+PS, &pgstat);
		get_pagestat(p+2*PS, &pgstat);
		printf("child hwpoison to vaddr %p\n", p+offset);
		madvise(&p[offset], PS, 100); /* hwpoison */
		put_semaphore(sem, &sembuf);
		get_semaphore(sem, &sembuf);
		puts("child terminated");
		put_semaphore(sem, &sembuf);
		get_pflags(pgstat.pfn, &pflag, 1);
		exit(EXIT_SUCCESS);
	} else {
		puts("parent dirty");
		usleep(1000);
		memset(wbuf, 49, nrpages * PS);
		pwrite(fd, wbuf, nrpages * PS, 0);
		tmp = pread(fd, rbuf, nrpages * PS, 0);
		printf("parent second read (after dirty) %d [%c,%c,%c]\n",
		       tmp, rbuf[0], rbuf[PS], rbuf[2*PS]);

		put_semaphore(sem, &sembuf); /* kick child to inject error */
		get_semaphore(sem, &sembuf); /* pagecache should be hwpoison */
		puts("parent check");

		/* trucate at offset PS*3/2 */
		if (ftruncate(fd, PS*3/2)) {
			perror("ftruncate");
		} else {
			printf("ftruncate succeeded.\n");
		}

		if (strcmp(actype, "read") == 0) {
			memset(rbuf, 0, nrpages * PS);
			if (pread(fd, rbuf, PS, 0) < 0)
				ret = -1;
			if (pread(fd, rbuf, PS, PS) < 0)
				ret = -1;
			if (pread(fd, rbuf, PS, 2*PS) < 0)
				ret = -1;
			if (ret == -1)
				perror("read");
		} else if (strcmp(actype, "write") == 0) {
			memset(wbuf, 50, nrpages * PS);
			if (pwrite(fd, wbuf, PS/4, 0) < 0)
				ret = -1;
			if (pwrite(fd, wbuf, PS/4, PS) < 0)
				ret = -1;
			if (pwrite(fd, wbuf, PS/4, 2*PS) < 0)
				ret = -1;
			if (ret == -1)
				perror("write");
		}
	}
	put_semaphore(sem, &sembuf);

	waitpid(pid, &wait_status, 0);
	if (!WIFEXITED(wait_status))
		err("waitpid");

	delete_semaphore(sem);
	printf("parent exit %d.\n", ret);
	return ret;
}
