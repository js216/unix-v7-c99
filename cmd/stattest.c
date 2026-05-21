#include <stdio.h>
#include <sys/stat.h>
extern int errno;
int chdir(char *p);
int unlink(char *p);
int chmod(char *p, int m);
int open(char *p, int f);
int close(int fd);
int dup(int from, int to);
int read(int fd, char *b, int n);
int write(int fd, char *b, int n);
long lseek(int fd, long o, int w);
int fstat(int fd, struct stat *s);
int main(void) {
    struct stat st;
    int r;
    long lr;
    char buf[16];
    errno = 0; r = stat("/nonexistent", &st);
    printf("stat(/nonexistent) ret=%d errno=%d\n", r, errno);
    errno = 0; r = chdir("/etc/passwd");
    printf("chdir(/etc/passwd) ret=%d errno=%d\n", r, errno);
    errno = 0; r = close(99);
    printf("close(99) ret=%d errno=%d\n", r, errno);
    errno = 0; r = read(99, buf, 1);
    printf("read(99) ret=%d errno=%d\n", r, errno);
    errno = 0; lr = lseek(99, 0L, 0);
    printf("lseek(99) ret=%ld errno=%d\n", lr, errno);
    errno = 0; r = fstat(99, &st);
    printf("fstat(99) ret=%d errno=%d\n", r, errno);
    errno = 0; r = dup(99, -1);
    printf("dup(99,-1) ret=%d errno=%d\n", r, errno);
    errno = 0; r = write(99, "x", 1);
    printf("write(99) ret=%d errno=%d\n", r, errno);
    return 0;
}
