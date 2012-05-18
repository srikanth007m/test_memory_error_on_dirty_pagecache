#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

int gate = 1;

void sighandle (int signo) {
	puts("user2 signal caught.");
	gate = 0;
}

int main(int argc, char *argv[]) {
	int fd;
	int i;
        char *p;
	char buf[PS];
        unsigned long length = 3;

	struct sigaction sa = {
		.sa_handler = sighandle,
	};
	if (sigaction(SIGUSR1, &sa, NULL) == -1)
		err("sigaction");

	fd = open_check("./test.txt", O_RDWR, 0);
	p = mmap_check((void *)REFADDR, 2 * PS,
			  PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	printf("user2 first read %p [%s]\n", p, p);
	while (gate) {
		p[0] = random() % 9 + 49;
	}
	for (i = 0; i < PS; i++) {
		p[0] = 'z';
	}
	printf("user2 second read (dirty) %p [%s]\n", p, p);
	puts("hwpoison");
	madvise(p, PS, 100); /* hwpoison */
	pause();
	puts("user2 exit.");
	return 0;
}
