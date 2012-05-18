#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

char buf[PS];

void sighandle (int signo) {
	puts("user1 signal caught.");
}

int main(int argc, char *argv[]) {
	int fd;
	int i;
        unsigned long length = 3;

	struct sigaction sa = {
		.sa_handler = sighandle,
	};
	if (sigaction(SIGUSR1, &sa, NULL) == -1)
		err("sigaction");

	fd = open_check("./test.txt", O_RDWR, 0);

	i = pread(fd, buf, PS, 0);
	printf("user1 first read %d [%s]\n", i, buf);

	pause();
	i = pread(fd, buf, PS, 0);
	printf("user1 second read (dirty) %d [%s]\n", i, buf);
	pause();
	i = pread(fd, buf, PS, 0);
	printf("user1 read after hwpoison %d [%s]\n", i, buf);
	pause();
	puts("user1 exit.");
	return 0;
}
