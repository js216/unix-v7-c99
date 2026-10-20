#include <stdio.h>
#include <signal.h>

extern int errno;
int phys(int segno, int size, int physaddr);
__asm__(
"	.text\n"
"	.globl phys\n"
"phys:\n"
"	mov ip, #52\n"
"	b cerror\n");

int caught;
void catch(int sig);

void
catch(int sig)
{
	caught = sig;
}

int
main(void)
{
	char *p[64];
	int i, bad, r;

	errno = 0;
	r = phys(3, 1, 0x9000);
	printf("phys: %d errno %d\n", r, errno);
	bad = 0;
	sbrk(4);
	for (i = 0; i < 64; i++) {
		p[i] = malloc(i*7 + 1);
		if ((int)p[i] & 7)
			bad++;
		if (i & 1)
			free(p[i/2]);
	}
	printf("malloc: %d of 64 blocks misaligned\n", bad);
	signal(16, catch);
	kill(getpid(), 16);
	printf("signal 16: caught %d\n", caught);
	errno = 0;
	r = (int)signal(17, catch);
	printf("signal 17: %d errno %d\n", r, errno);
	return 0;
}
