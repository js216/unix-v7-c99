#include <stdio.h>
int fork(void); int wait(int *); void _exit(int);
int main(void) {
    int codes[] = {0, 1, 42, 255, -1};
    int i;
    for (i = 0; codes[i] != -1; i++) {
        int pid = fork();
        if (pid == 0) {
            _exit(codes[i]);
        }
        int status = 0;
        wait(&status);
        int exit_code = (status >> 8) & 0xff;
        int sig = status & 0x7f;
        printf("exit(%d) -> status=0x%x sig=%d exit=%d\n",
            codes[i], status, sig, exit_code);
    }
    return 0;
}
