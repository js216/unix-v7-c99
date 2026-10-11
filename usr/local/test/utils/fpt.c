#include <stdio.h>
#include <signal.h>
#include "h/param.h"
#include "h/dir.h"
#include "h/user.h"

volatile double one = 1.0, three = 3.0, ten = 10.0, zero = 0.0, big = 1e308;
volatile double v = 1234.5, h[32];
volatile int got;

#define	RN	0
#define	RP	(1U<<22)
#define	RM	(2U<<22)
#define	RZ	(3U<<22)
#define	FLAGS	0x9fU
#define	CTL(x)	((x) & 0x07ffff00U)

static void
bits(char *s, double d)
{
	union { double d; unsigned u[2]; } x;

	x.d = d;
	printf("%s %08x%08x\n", s, x.u[1], x.u[0]);
}

static void
flags(char *s)
{
	printf("%s flags %02x\n", s, __builtin_arm_get_fpscr() & FLAGS);
	__builtin_arm_set_fpscr(__builtin_arm_get_fpscr() & ~FLAGS);
}

static void
ieee(void)
{
	static char *mn[] = { "rn", "rp", "rm", "rz" };
	char s[16];
	unsigned m;
	double t;

	printf("fpscr %08x\n", __builtin_arm_get_fpscr());
	bits("1/3", one/three);
	bits("0.1+0.2", one/ten + 2*(one/ten));
	flags("inexact");
	bits("max*10", big*ten);
	flags("overflow");
	t = one;
	for (m = 0; m < 1074; m++)
		t /= 2;
	bits("2^-1074", t);
	bits("2^-1075", t/2);
	flags("underflow");
	bits("1/0", one/zero);
	flags("divide");
	bits("0/0", zero/zero);
	flags("invalid");
	for (m = 0; m < 4; m++) {
		__builtin_arm_set_fpscr(m<<22);
		sprintf(s, "%s 1/10", mn[m]);
		bits(s, one/ten);
		sprintf(s, "%s -1/10", mn[m]);
		bits(s, -one/ten);
	}
	__builtin_arm_set_fpscr(0);
}

static int
check(unsigned mode, int n)
{
	double a, b, c, q;
	int i, bad;

	bad = 0;
	q = one/ten;
	a = b = c = 0;
	for (i = 0; i < n; i++) {
		a += one;
		b += three;
		c -= ten;
	}
	if (b != 3*a || c != -10*a || a != n)
		bad |= 1;
	if (one/ten != q || CTL(__builtin_arm_get_fpscr()) != mode)
		bad |= 2;
	return(bad);
}

static int
reader(void)
{
	int pid, fd;
	char buf[512];

	if ((pid = fork()) == 0) {
		fd = open("/dev/rrk0", 0);
		for (;;)
			read(fd, buf, 512);
	}
	return(pid);
}

static void
swtch(void)
{
	int p1[2], p2[2], i, pid, rd, st, bad;
	double s;
	char c;

	pipe(p1);
	pipe(p2);
	if ((pid = fork()) == 0) {
		__builtin_arm_set_fpscr(RM);
		bad = 0;
		for (s = 0, i = 0; i < 2000; i++) {
			read(p1[0], &c, 1);
			s += one/zero;
			bad |= check(RM, 50);
			write(p2[1], &c, 1);
		}
		bad |= check(RM, 5000000);
		printf("child %s %d\n", bad ? "bad" : "ok", bad);
		exit(0);
	}
	__builtin_arm_set_fpscr(RP);
	bad = 0;
	for (s = 0, i = 0; i < 2000; i++) {
		s += three;
		write(p1[1], &c, 1);
		read(p2[0], &c, 1);
		bad |= check(RP, 50);
	}
	if (s != 6000 || __builtin_arm_get_fpscr() & 2)
		bad |= 4;
	rd = reader();
	bad |= check(RP, 5000000);
	while (wait(&st) != pid)
		;
	kill(rd, SIGKILL);
	wait(&st);
	printf("parent %s %d\n", bad ? "bad" : "ok", bad);
}

static void
catch(int sig)
{
	int i;
	double t;

	(void)sig;
	__builtin_arm_set_fpscr(RN);
	for (t = 0, i = 0; i < 32; i++)
		h[i] = t += one/three + i;
	h[0] = one/zero;
	got++;
}

static void
sig(void)
{
	double a, b, c, d;
	int pid, kid, fd, st;
	unsigned i, f;
	char buf[512];

	signal(SIGTRAP, catch);
	__builtin_arm_set_fpscr(RZ);
	a = v * 2;
	kill(getpid(), SIGTRAP);
	f = __builtin_arm_get_fpscr() & 0x07ffffffU;
	printf("sync %d fpscr %08x %s\n", got, f,
	    a == 2469.0 ? "ok" : "bad");
	pid = getpid();
	if ((kid = fork()) == 0) {
		fd = open("/dev/rrk0", 0);
		for (;;) {
			kill(pid, SIGTRAP);
			read(fd, buf, 512);
		}
	}
	a = b = c = d = 0;
	for (i = 0; got < 20 && i < 400000000; i++) {
		a += one;
		b += three;
		c -= ten;
		d = d*one + 1;
	}
	kill(kid, SIGKILL);
	wait(&st);
	printf("async %s %s fpscr %08x\n", got >= 20 ? "done" : "timeout",
	    b == 3*a && c == -10*a && d == a ? "ok" : "bad",
	    __builtin_arm_get_fpscr() & 0x07ffffffU);
}

static void
core(void)
{
	double x;

	__builtin_arm_set_fpscr(RZ | 2);
	x = v * 2;
	kill(getpid(), SIGQUIT);
	printf("%g\n", x);
}

static void
rcore(void)
{
	static struct user cu;
	int fd, i, n;

	fd = open("core", 0);
	if (fd < 0 || read(fd, (char *)&cu, sizeof(cu)) != sizeof(cu)) {
		printf("no core\n");
		return;
	}
	close(fd);
	for (n = i = 0; i < 32; i++)
		if (cu.u_fps.u_fpregs[i] == 2469.0)
			n++;
	printf("core fpscr %08x 2469 %s\n", cu.u_fps.u_fpsr, n ? "found" : "missing");
}

static void
forkt(char *self)
{
	int st;
	double x;

	__builtin_arm_set_fpscr(RP);
	x = v * 2;
	if (fork() == 0) {
		printf("child fpscr %08x %s\n", CTL(__builtin_arm_get_fpscr()),
		    x == 2469.0 ? "ok" : "bad");
		fflush(stdout);
		execl(self, "fpt", "exec", (char *)0);
		exit(1);
	}
	wait(&st);
	printf("parent fpscr %08x %s\n", CTL(__builtin_arm_get_fpscr()),
	    x == 2469.0 ? "ok" : "bad");
}

int
main(int argc, char **argv)
{
	if (argc < 2)
		return(1);
	switch (argv[1][0]) {
	case 'i':
		ieee();
		break;
	case 's':
		if (argv[1][1] == 'w')
			swtch();
		else
			sig();
		break;
	case 'c':
		core();
		break;
	case 'r':
		rcore();
		break;
	case 'f':
		forkt(argv[0]);
		break;
	case 'e':
		printf("exec fpscr %08x\n", __builtin_arm_get_fpscr());
		break;
	}
	return(0);
}
