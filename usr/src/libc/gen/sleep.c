#include <signal.h>
#include <setjmp.h>
#include <stdio.h>

static jmp_buf jmp;
static void sleepx();

unsigned
sleep(n)
volatile unsigned n;
{
	volatile unsigned altime;
	int (*volatile alsig)() = SIG_DFL;

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
sleepx()
{
	longjmp(jmp, 1);
}
