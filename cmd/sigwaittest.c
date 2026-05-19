#include <stdio.h>
#include <signal.h>
int fork(void); int wait(int *); int kill(int,int); int getpid(void);
int
main(void) {
    int pid = fork();
    if (pid == 0) {
        for(;;);  /* spin forever */
    }
    /* parent: kill child after a moment via SIGKILL */
    kill(pid, 9);
    int status = 0;
    int reaped = wait(&status);
    printf("reaped=%d status=0x%x sig=%d exit=%d\n",
        reaped, status, status & 0x7f, (status >> 8) & 0xff);
    return 0;
}
