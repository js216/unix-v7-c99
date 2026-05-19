#include <stdio.h>
int fork(void); int wait(int *); int getppid(void); unsigned sleep(unsigned);
int main(void) {
    int pid = fork();
    if (pid == 0) {
        /* child: sleep a bit, then check ppid */
        sleep(2);
        printf("child ppid after parent exit: %d\n", getppid());
        return 0;
    }
    /* parent: exit immediately, orphaning the child */
    printf("parent exiting, child=%d\n", pid);
    return 0;
}
