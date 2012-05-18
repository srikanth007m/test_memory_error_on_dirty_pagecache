#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>

#include "mystd.h"
#include "mymman.h"

#define REFADDR 0x700000000000

void sighandle (int signo) { puts("signal caught."); }

int main(int argc, char *argv[]) {
	/* char *p = malloc(10 * PS); */
	int fd = open("/tmp/3", O_RDWR|O_CREAT, 0666);
	/* char *p = mmap(NULL, 10 * PS, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0); */
	char *p = mmap(NULL, 10 * PS, PROT_READ|PROT_WRITE, MAP_PRIVATE, -1, 0);
	printf("p = %p\n", p);
	memset(p, 0, 10*PS);
}
