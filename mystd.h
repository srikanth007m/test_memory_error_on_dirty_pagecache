#include <stdio.h>
#include <errno.h>
#include <stdlib.h>

#define err(msg) do { perror(msg); exit(EXIT_FAILURE); } while(0)

#ifdef DEBUG
#define DEB(fmt, args...) printf(fmt, ##args)
#else
#define DEB(fmt, ...)
#endif

#define PS      4096
#define PSIZE   PS
#define HPS     512*4096
#define HPSIZE  HPS
