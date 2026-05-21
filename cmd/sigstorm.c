#include <stdio.h>
#include <signal.h>
int kill(int,int); int getpid(void); int write(int,char*,int);
unsigned sleep(unsigned);
void h(int s){ (void)s; write(1, "H\n", 2); }
int main(void) {
    int pid = getpid();
    write(1, "A\n", 2);
    signal(2, (int)h);
    write(1, "B\n", 2);
    kill(pid, 2);
    sleep(0);  /* give kernel a chance to deliver signal */
    write(1, "C\n", 2);
    return 0;
}
