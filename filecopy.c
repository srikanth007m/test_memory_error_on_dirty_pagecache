#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

void sighandle (int signo) { puts("signal caught."); }

int main(int argc, char *argv[]) {
	int fdold;
	int fdnew;
	int i;
        char *pold;
        char *pnew;
	char buf[PS];
        unsigned long length = 3;

	struct sigaction sa = {
		.sa_handler = sighandle,
	};
	if (sigaction(SIGUSR1, &sa, NULL) == -1)
		err("sigaction");

	fdold = open_check("./tmp.old", O_RDWR, 0);
	fdnew = open_check("./tmp.new", O_RDWR|O_CREAT, 0666);
	DEB("fdold %d, fdnew %d\n", fdold, fdnew);

	for (i = 0; i < length; i++) {
		int ret;
		if ((ret = read(fdold, buf, PS)) != PS)
			fprintf(stderr, "Read only partially (%d/%d)\n", ret, PS);
		DEB("read %d\n", ret);
		if ((ret = write(fdnew, buf, PS)) != PS)
			fprintf(stderr, "Write only partially (%d/%d)\n", ret, PS);
		DEB("write %d\n", ret);
	}

	puts("Copied data from oldfile to newfile.");
	pause();

	pold = mmap_check((void *)REFADDR, length * PS,
			  PROT_READ|PROT_WRITE, MAP_SHARED, fdold, 0);
	pnew = mmap_check((void *)(REFADDR + 0x1000000UL), length * PS,
			  PROT_READ|PROT_WRITE, MAP_SHARED, fdnew, 0);
	DEB("pold %p, pnew %p\n", pold, pnew);

	for (i = 0; i < length; i++) {
		char c;
		c = pold[i * PS];
		c = pnew[i * PS];
	}
	puts("mmap");
	pause();

	munmap_check(pold, length * PS);
	munmap_check(pnew, length * PS);

	puts("munmap");
	pause();

	puts("fsync");
	pause();

	close_check(fdold);
	close_check(fdnew);

	puts("Finish successfully.");
	return 0;
}
