#include <signal.h>
#include <setjmp.h>
#include <stdio.h>

static jmp_buf jmp;
static void sleepx(int sig);

unsigned
sleep(volatile unsigned n)
{
	volatile unsigned altime;
	void (*volatile alsig)(int sig) = SIG_DFL;

	if (n==0)
		return(0);
	altime = alarm(1000);	/* time to maneuver */
	if (setjmp(jmp)) {
		signal(SIGALRM, alsig);
		alarm(altime);
		return(0);
	}
	if (altime) {
		if (altime > n)
			altime -= n;
		else {
			n = altime;
			altime = 1;
		}
	}
	alsig = signal(SIGALRM, sleepx);
	alarm(n);
	for(;;)
		pause();
	/*NOTREACHED*/
}

static void
sleepx(int sig)
{
	(void)sig;
	longjmp(jmp, 1);
}
