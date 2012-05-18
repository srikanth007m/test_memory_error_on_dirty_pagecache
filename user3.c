#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

int gate = 1;
char rbuf[PS];
char wbuf[PS];

void sighandle (int signo) {
	puts("user3 signal caught.");
	gate = 0;
}

int main(int argc, char *argv[]) {
	int fd;
	int i;
	int j = 0;

	struct sigaction sa = {
		.sa_handler = sighandle,
	};
	if (sigaction(SIGUSR1, &sa, NULL) == -1)
		err("sigaction");

	fd = open_check("./test.txt", O_RDWR, 0);

	pread(fd, rbuf, PS, 0);
	printf("user3 first read [%s]\n", rbuf);

	while (gate) {
		j++;
		pread(fd, rbuf, PS, 0);
		sprintf(wbuf, "%d", strtol(rbuf, NULL, 10) + 1);
		pwrite(fd, wbuf, strlen(wbuf), 0);
	}

	pread(fd, rbuf, PS, 0);
	printf("user3 read after hwpoison %d [%s]\n", j, rbuf);
	pause();
	puts("user3 exit.");
	return 0;
}
