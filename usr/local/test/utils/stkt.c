#include <stdio.h>
#include <signal.h>

int caught;
void catch(int sig);
int f(int n);

void
catch(int sig)
{
	caught++;
	signal(sig, catch);
}

int
f(int n)
{
	unsigned char buf[1000];
	int i;

	for (i = 0; i < 1000; i++)
		buf[i] = n + i;
	kill(getpid(), SIGINT);
	if (n == 0)
		return buf[999];
	return f(n - 1) + buf[n % 1000];
}

int
main(void)
{
	signal(SIGINT, catch);
	printf("sum %d caught %d\n", f(400), caught);
	return 0;
}
