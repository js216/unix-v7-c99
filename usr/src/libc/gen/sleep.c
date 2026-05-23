#include <setjmp.h>


static jmp_buf sleep_jmp;
static void
sleepx(int signo)
{
	(void)signo;
	longjmp(sleep_jmp, 1);
}
extern int signal(int sig, void (*fun)(int));
extern int alarm(int n);
extern int pause(void);
unsigned
sleep(unsigned n)
{
	unsigned altime;
	void (*alsig)(int) = (void (*)(int))0;
	if(n == 0)
		return(0);
	altime = (unsigned)alarm(1000);
	if(setjmp(sleep_jmp)) {
		(void)signal(14, alsig);
		(void)alarm((int)altime);
		return(0);

	}
	if(altime) {
		if(altime > n)
			altime -= n;
		else {
			n = altime;
			altime = 1;
		}
	}
	alsig = (void (*)(int))(long)signal(14, sleepx);
	(void)alarm((int)n);
	for(;;)
		(void)pause();
}
