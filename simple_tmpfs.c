#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

char buf[4096];

int main() {
	int ret;
	int fd = open("/media/sample", O_CREAT|O_RDWR, 0777);
	printf("fd %d\n", fd);
	memset(buf, 54, 4096);
	ret = write(fd, buf, 4096);
	perror("write");
	printf("Wrote %d bytes.\n", ret);
	ret = pwrite(fd, buf, 4096, 4096);
	printf("Wrote %d bytes.\n", ret);

	char c;
	char *p = mmap((void *)0x700000000000, 2*4096,
		       PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	printf("p %p.\n", p);
	c = p[0]; c = p[4096];
	madvise(p, 1, 100);
	pause();
	return 0;
}
