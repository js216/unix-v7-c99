/*
 * fzsys seed batches: random system calls with hostile arguments.
 * Each batch runs in a child as the user dmr (uid 7, group 3), with
 * its standard files on /dev/null, in /tmp/fz/sys.  The child makes
 * random calls by number, through svc, with arguments drawn from
 * classes that reach the edges of the kernel's checks: small and
 * huge numbers, file descriptors, pointers into its own memory, into
 * its read-only text, at the ends of its data, and into the kernel's
 * gigabyte, and names which are long, empty, or not ended.  fork and
 * exec are left to fzproc and fzelf.  The kernel must never panic,
 * the child must never gain root, and no file of the system may
 * change.  After each call the child tries to create /fzroot, which
 * only root can; its exit status proves nothing, since a random
 * signal handler may send it anywhere in its own code.  Prints the seed and batch on the first difference and
 * exits 1; prints "fzsys ok" otherwise.
 */

#include <stdio.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	NCALL	300
#define	BUFSZ	8192
#define	FUZZUID	7
#define	FUZZGID	3
#define	PROOF	"/fzroot"

unsigned	rawsys(unsigned n, unsigned a, unsigned b, unsigned c, unsigned d);
unsigned	rawerr;
__asm__(
"	.text\n"
"	.globl rawsys\n"
"rawsys:\n"
"	push {r4-r7, lr}\n"
"	mov r7, r0\n"
"	mov r0, r1\n"
"	mov r1, r2\n"
"	mov r2, r3\n"
"	ldr r3, [sp, #20]\n"
"	svc #0\n"
"	ldr r2, =rawerr\n"
"	movcs r3, #1\n"
"	movcc r3, #0\n"
"	str r3, [r2]\n"
"	pop {r4-r7, pc}\n"
"	.ltorg\n");

char	*name[] = {
	"a", "b", "d/e", "/tmp/fz/sys/a", "/tmp/fz/sys", ".", "..", "/",
	"/dev/null", "", "/etc/passwd", "/bin/ls", "/unix", "/usr/local",
	"a/../a", "////", "d", "/dev/mem", "/dev/kmem", "/dev/rrk0",
};
#define	NNAME	(sizeof(name)/sizeof(name[0]))
char	*watch[] = { "/etc/passwd", "/etc/group", "/unix", "/bin/sh",
	"/etc/init", "/bin/ls" };
#define	NWATCH	(sizeof(watch)/sizeof(watch[0]))
struct	stat	before[NWATCH];
unsigned long	rs;
long	seed;
int	batch;
char	buf[BUFSZ];
char	longname[600];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(n ? rs % n : (unsigned)rs);
}

static void
fail(char *what)
{
	printf("FAIL fzsys seed %ld batch %d: %s\n", seed, batch, what);
	exit(1);
}

static unsigned
arg(void)
{
	static unsigned edge[] = {
		0, 1, 2, 3, 4, 0x7fffffff, 0x80000000, 0xffffffff, 0xfffffffe,
		0xc0000000, 0xc0000ffc, 0xc01e0000, 0xbffffffc, 0xbffff000,
		0xffe00000, 0xffe00ffc, 0xfffff000, 0x1000, 0x8000, 4096,
		512, 513, 65536, 0x40000000,
	};

	switch(rnd(12)) {
	case 0: case 1:
		return(rnd(25));
	case 2:
		return(edge[rnd(sizeof(edge)/sizeof(edge[0]))]);
	case 3: case 4:
		return((unsigned)(buf + rnd(BUFSZ)));
	case 5:
		return((unsigned)(buf + BUFSZ - rnd(8)));
	case 6: case 7:
		return((unsigned)name[rnd(NNAME)]);
	case 8:
		return((unsigned)longname + rnd(40));
	case 9:
		return((unsigned)&rnd + rnd(64));
	case 10:
		return(rnd(0) | 1);
	default:
		return(rnd(0));
	}
}

static void
child(void)
{
	int i, n, fd;

	for(fd = 0; fd < 20; fd++)
		close(fd);
	open("/dev/null", 2);
	dup(0);
	dup(0);
	signal(SIGALRM, SIG_DFL);
	if(setgid(FUZZGID) < 0 || setuid(FUZZUID) < 0 || getuid() != FUZZUID)
		exit(9);
	chdir("/tmp/fz/sys");
	for(i = 0; i < BUFSZ; i++)
		buf[i] = rnd(256);
	for(i = 0; i < (int)sizeof(longname)-1; i++)
		longname[i] = 'a' + i%26;
	for(i = 0; i < NCALL; i++) {
		do
			n = rnd(70);
		while(n == 1 || n == 2 || n == 11 || n == 59);
		rawsys(n, arg(), arg(), arg(), arg());
		if(creat(PROOF, 0644) >= 0)
			exit(8);
	}
	exit(0);
}

static int
same(struct stat *a, struct stat *b)
{
	return(a->st_ino == b->st_ino && a->st_mode == b->st_mode &&
	    a->st_uid == b->st_uid && a->st_size == b->st_size &&
	    a->st_mtime == b->st_mtime && a->st_nlink == b->st_nlink);
}

static void
timeout(int sig)
{
	(void)sig;
}

int
main(int argc, char **argv)
{
	struct stat st;
	int i, nbatch, pid, w, status;

	if(argc != 3) {
		printf("usage: fzsys seed batches\n");
		exit(2);
	}
	seed = atol(argv[1]);
	nbatch = atoi(argv[2]);
	for(i = 0; i < (int)NWATCH; i++)
		if(stat(watch[i], &before[i]) < 0)
			fail("stat before");
	if((pid = fork()) == 0) {
		if(setgid(FUZZGID) < 0 || setuid(FUZZUID) < 0 ||
		    getuid() != FUZZUID || creat(PROOF, 0644) >= 0)
			exit(9);
		exit(0);
	}
	while((w = wait(&status)) != pid && w >= 0)
		;
	if(w < 0 || status != 0)
		fail("cannot become dmr");
	for(batch = 0; batch < nbatch; batch++) {
		rs = seed*2654435761UL + batch*40503UL + 11;
		if((pid = fork()) < 0)
			fail("fork");
		if(pid == 0)
			child();
		signal(SIGALRM, timeout);
		alarm(3);
		while((w = wait(&status)) != pid)
			if(w < 0) {
				kill(pid, SIGKILL);
				alarm(0);
			}
		alarm(0);
		if(stat(PROOF, &st) == 0) {
			unlink(PROOF);
			fail("the child became root");
		}
		for(i = 0; i < (int)NWATCH; i++)
			if(stat(watch[i], &st) < 0 || !same(&st, &before[i]))
				fail(watch[i]);
	}
	printf("fzsys ok\n");
	exit(0);
}
