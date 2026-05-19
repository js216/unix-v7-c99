#include <stdio.h>
#include <signal.h>
int handler_count = 0;
int sigalrm_handler(int s) {
    (void)s;
    handler_count++;
    printf("handler #%d\n", handler_count);
    return 0;
}
int main(void) {
    signal(SIGALRM, (int)sigalrm_handler);
    alarm(1);
    pause();
    printf("after first pause, count=%d\n", handler_count);
    alarm(1);
    pause();
    printf("after second pause, count=%d (handler not re-installed)\n", handler_count);
    return 0;
}
