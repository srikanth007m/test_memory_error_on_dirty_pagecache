#include <stdio.h>
#include <signal.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
	int fd;
	char *filename;
	if (argc != 2) {
		printf("Need filepath as an argument\n");
		exit(EXIT_FAILURE);
	}
	filename = argv[1];
	fd = open(filename, O_RDONLY);
	if (fd < 0) {
		err(1, "open");
		exit(EXIT_FAILURE);
	}
	pause();
}
