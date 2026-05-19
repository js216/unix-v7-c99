#include <stdio.h>
int fork(void); int wait(int *);
int main(void) {
    int pid = fork();
    if (pid == 0) {
        /* undefined ARM instruction encoding (used by gcc for __builtin_trap) */
        __asm__ volatile(".inst 0xe7f000f0");
        printf("FAIL: undef did not fault\n");
        return 0;
    }
    int status = 0;
    int reaped = wait(&status);
    int sig = status & 0x7f;
    if (sig == 4) {
        printf("PASS killed sig=4 (SIGILL)\n");
    } else {
        printf("FAIL reaped=%d status=0x%x sig=%d\n", reaped, status, sig);
    }
    return 0;
}
