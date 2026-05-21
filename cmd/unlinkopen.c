#include <stdio.h>
int open(char *p, int f);
int read(int fd, char *b, int n);
int write(int fd, char *b, int n);
int close(int fd);
int unlink(char *p);
int creat(char *p, int m);
int main(void) {
    int fd, n;
    char buf[64];
    fd = creat("/tmp/uo", 0644);
    if(fd < 0) { printf("creat fail\n"); return 1; }
    write(fd, "hello world\n", 12);
    close(fd);
    fd = open("/tmp/uo", 0);
    if(fd < 0) { printf("open fail\n"); return 1; }
    if(unlink("/tmp/uo") < 0) printf("unlink fail\n");
    /* Read while unlinked but still open */
    n = read(fd, buf, sizeof(buf)-1);
    if(n > 0) { buf[n] = 0; printf("read after unlink: '%s'\n", buf); }
    else printf("read returned %d\n", n);
    close(fd);
    return 0;
}
