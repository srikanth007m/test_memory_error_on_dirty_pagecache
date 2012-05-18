#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

char buf[4096];

/* use this program with insert_stap_probe3.sh */

int main() {
	int ret;
	int fd = open("./simple_owc", O_CREAT|O_RDWR, 0777);
	memset(buf, 0, 4096);
	ret = write(fd, buf, 4096);
	close(fd);
	return 0;
}
