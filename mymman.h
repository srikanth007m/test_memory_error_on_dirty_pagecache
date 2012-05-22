#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#include "mystd.h"

int open_check(char *str, int flags, mode_t mode) {
	int fd;
	if (mode)
		fd = open(str, flags, mode);
	else
		fd = open(str, flags);
	if (fd == -1)
		err("open");
	return fd;
}

int close_check(int fd) {
	if (close(fd) == -1)
		err("close");
	return 0;
}

void *mmap_check(void *start, size_t length, int prot, int flags,
		   int fd, off_t offset) {
        void *map = mmap(start, length, prot, flags, fd, offset);
	if (map == (void*)-1L)
                err("mmap");
        return map;
}

int *munmap_check(void *start, size_t length) {
	if (munmap(start, length) == -1)
                err("munmap");
        return 0;
}
