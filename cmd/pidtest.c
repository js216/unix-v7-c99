#include <stdio.h>
int getpid(void);
int getppid(void);
int main(void) {
    printf("pid=%d ppid=%d\n", getpid(), getppid());
    return 0;
}
