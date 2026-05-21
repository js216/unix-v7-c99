#include <stdio.h>
#include <signal.h>
int caught = 0;
int fork(void); int kill(int,int); int wait(int*); unsigned sleep(unsigned);
int getpid(void); int getppid(void);
void handler(int s){ caught++; printf("parent caught sig=%d count=%d\n", s, caught); }
int main(void) {
    int pid;
    signal(2, (int)handler);  /* SIGINT */
    pid = fork();
    if(pid == 0) {
        sleep(1);
        kill(getppid(), 2);
        return 0;
    }
    sleep(3);
    printf("after sleep, caught=%d\n", caught);
    wait(0);
    return 0;
}
