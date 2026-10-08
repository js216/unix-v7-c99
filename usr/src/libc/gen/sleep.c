#include <signal.h>
#include <setjmp.h>

static jmp_buf jmp;
static void sleepx(int signo);
int	signal();
extern int alarm(int n);
extern int pause(void);

unsigned
sleep(volatile unsigned n)
{
	unsigned altime;
	int alsig = SIG_DFL;

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
	alsig = signal(SIGALRM, (int)sleepx);
	alarm(n);
	for(;;)
		pause();
	/*NOTREACHED*/
}

static void
sleepx(int signo)
{
	(void)signo;
	longjmp(jmp, 1);
}
