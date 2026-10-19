#include <stdio.h>
#include <signal.h>

int tsig4(int pid, int sig);
__asm__(
"	.syntax unified\n"
"	.text\n"
"	.thumb\n"
"	.globl tsig4\n"
"	.type tsig4, %function\n"
"	.thumb_func\n"
"tsig4:\n"
"	push {r4, r7, lr}\n"
"	movs r4, #0\n"
"	movs r7, #37\n"
"	cmp r0, r0\n"
"	itete eq\n"
"	svceq #0\n"
"	addne r4, #1\n"
"	addeq r4, #2\n"
"	addne r4, #4\n"
"	mov r0, r4\n"
"	pop {r4, r7, pc}\n"
"	.align 2\n"
"	.arm\n");

volatile int hits;

static void
count(int sig)
{
	signal(sig, count);
	hits++;
}

static int
padded(char *name)
{
	unsigned h[13], p[8], i;
	int fd, r;

	r = 0;
	if ((fd = open(name, 0)) < 0)
		return 0;
	if (read(fd, (char *)h, 52) == 52 && h[0] == 0x464c457f)
		for (i = 0; i < (h[11] & 0xffff); i++) {
			lseek(fd, (long)(h[7] + 32*i), 0);
			if (read(fd, (char *)p, 32) != 32)
				break;
			if (p[0] == 1) {
				r = p[1] != 0;
				break;
			}
		}
	close(fd);
	return r;
}

int
main(int argc, char **argv)
{
	long long ll;
	int i, n;

	if (argc > 2 && argv[1][0] == 'a') {
		for (n = atoi(argv[2]); n > 0; n--)
			putchar('@');
		putchar('\n');
		return 0;
	}
	if (argc > 1) {
		for (n = 0, i = 2; i < argc; i++)
			n += padded(argv[i]);
		printf("padded %d\n", n);
		return 0;
	}
	signal(SIGALRM, count);
	printf("thumb it4: %d hits %d\n", tsig4(getpid(), SIGALRM),
	    hits);
	sscanf("99999999999999999999", "%lld", &ll);
	sscanf("777777777777777777777777", "%o", &i);
	printf("scan %lld %o\n", ll, i);
	printf("[%.s][%.f][%.e][%.2s][%.*s][%.0f]\n", "abc", 1.5, 1.5,
	    "abc", 1, "abc", 1.25);
	return 0;
}
