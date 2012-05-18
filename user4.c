#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

char buf[PS];

void sighandle (int signo) {
	puts("user4 signal caught.");
}

int main(int argc, char *argv[]) {
	int i;
	int fd;
        char *p;

	struct sigaction sa = {
		.sa_handler = sighandle,
	};
	if (sigaction(SIGUSR1, &sa, NULL) == -1)
		err("sigaction");

	fd = open_check("./test.txt", O_RDWR, 0);
	p = mmap_check((void *)REFADDR, 2 * PS,
			  PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

	printf("user4 first read %p [%s]\n", p, p);
	pause();
	printf("user4 second read (dirty) %p [%s]\n", p, p);
	puts("hwpoison");
	madvise(p, PS, 100); /* hwpoison */
	pause();
	puts("user4 exit.");
	return 0;
}
