/*
 * Usage: ./test filename flag nrpages
 * flag = 0 // parent read() after hwpoison injection
 * flag = 1 // parent fsync() after hwpoison injection
 * flag = 2 // parent write() after hwpoison injection
 * pages: nr of pages (only 1 or 2 are supported now.)
 */
#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

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

int main(int argc, char *argv[]) {
	int fd;
	int sem;
	int flag = 0;
	int nrpages = 1;
	int ret = 0;
	char *p;
	char *filename;
	pid_t pid;
	int wait_status;
	uint64_t pflag;
	struct sembuf sembuf;
	struct pagestat pgstat;

	if (argc != 4) {
		printf("Usage: %s filename flag nrpages\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	filename = argv[1];
	flag = strtol(argv[2], NULL, 10);
	nrpages = strtol(argv[3], NULL, 10);
	printf("filename = %s, flag = %d, nrpages = %d\n",
	       filename, flag, nrpages);

	sem = create_and_init_semaphore();

	fd = open_check(filename, O_RDWR, 0);
	ret = pread(fd, rbuf, nrpages*PS, 0);
	printf("parent first read %d [%c,%c]\n", ret, rbuf[0], rbuf[PS]);

	get_semaphore(sem, &sembuf);
	if ((pid = fork()) == 0) {
		get_semaphore(sem, &sembuf); /* wait parent to dirty page */
		p = mmap_check((void *)REFADDR, nrpages * PS,
			       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
		if (p != (void *)REFADDR)
			err("mmap");
		if (nrpages == 1) {
			printf("child read (after dirty) [%c]\n", p[0]);
			get_pagestat(p, &pgstat);
		} else {
			printf("child read (after dirty) [%c,%c]\n", p[0], p[PS]);
			get_pagestat(p, &pgstat);
			get_pagestat(p+PS, &pgstat);
		}
		printf("child hwpoison to vaddr %p\n", p);
		madvise(p, PS, 100); /* hwpoison */
		put_semaphore(sem, &sembuf);
		get_semaphore(sem, &sembuf);
		puts("child terminated");
		put_semaphore(sem, &sembuf);
		get_pflags(pgstat.pfn, &pflag, 1);
		exit(EXIT_SUCCESS);
	} else {
		puts("parent dirty");
		usleep(1000);
		pread(fd, rbuf, nrpages * PS, 0);
		sprintf(wbuf, "%d", strtol(rbuf, NULL, 10) + 1);
		sprintf(wbuf+PS, "%d", strtol(rbuf, NULL, 10) + 1);
		pwrite(fd, wbuf, nrpages * PS, 0);
		ret = pread(fd, rbuf, nrpages * PS, 0);
		printf("parent second read (after dirty) %d [%c,%c]\n",
		       ret, rbuf[0], rbuf[PS]);

		put_semaphore(sem, &sembuf); /* kick child to inject error */
		get_semaphore(sem, &sembuf); /* pagecache should be hwpoison */
		puts("parent check");
		if (flag == 0) {
			ret = pread(fd, rbuf, nrpages * PS, 0);
			printf("parent read after hwpoison %d [%c,%c]\n",
			       ret, rbuf[0],rbuf[PS]);
			if (ret < 0)
				perror("read");
			ret = pread(fd, rbuf, nrpages * PS, 0);
			printf("parent read after hwpoison %d [%c,%c]\n",
			       ret, rbuf[0],rbuf[PS]);
			if (ret < 0)
				perror("read");
		} else if (flag == 1) {
			ret = fsync(fd);
			printf("parent fsync after hwpoison [ret %d]\n", ret);
			if (ret)
				perror("fsync");
			ret = fsync(fd);
			printf("parent fsync after hwpoison [ret %d]\n", ret);
			if (ret)
				perror("fsync");
		} else if (flag == 2) {
			sprintf(wbuf, "%d", strtol(rbuf, NULL, 10) + 1);
			sprintf(wbuf+PS, "%d", strtol(rbuf, NULL, 10) + 1);
			ret = pwrite(fd, wbuf, nrpages * PS, 0);
			printf("parent write after hwpoison %d\n", ret);
			if (ret < 0)
				perror("write");
			ret = pwrite(fd, wbuf, nrpages * PS, 0);
			printf("parent write after hwpoison %d\n", ret);
			if (ret < 0)
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
