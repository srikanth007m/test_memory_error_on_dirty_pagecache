#include <stdio.h>
#include <unistd.h>
#include <signal.h>

#include "mystd.h"
#include "mymman.h"

void sighandler(int signo) { ; }

int main (int argc, char **argv) {
	int ret = 0;
	int fd;
	char *filename;
	char rbuf[PS];

	if (argc != 2) {
		printf("Usage: %s filename\n", argv[0]);
		exit(EXIT_FAILURE);
	}
	filename = argv[1];
	signal(SIGUSR1, sighandler);

	fd = open_check(filename, O_RDWR, 0);
	pause();
	if (pread(fd, rbuf, PS, 0) < 0) {
		perror("read");
		ret = 1;
	}
	close_check(fd);
	return ret;
}
