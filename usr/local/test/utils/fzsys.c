/*
 * fzsys [-s] seed batches [first [calls]]: random system calls with
 * hostile arguments, in batches first (0) to batches-1, of calls (300)
 * each.  With -s, safe for the board's SD card, only calls which can
 * change no file, in /, which the child cannot write, so that it
 * makes no core file either.
 * Each batch runs in a child as uid 8, which no one else uses, with
 * its standard files on /dev/null, in /tmp/fz/sys.  The child makes
 * random calls by number, through svc, with arguments drawn from
 * classes that reach the edges of the kernel's checks: small and
 * huge numbers, file descriptors, pointers into its own memory, into
 * its read-only text, at the ends of its data, and into the kernel's
 * gigabyte, and names which are long, empty, or not ended.  fork and
 * exec, also under the numbers 64 higher which the kernel's mask of 077
 * maps onto them, are left to fzproc and fzelf.  The kernel must never
 * panic, the child must never gain root, and no file of the system may
 * change, though it may gain links, which any user may make.  After
 * each call the child tries to create /fzroot, which only root can;
 * its exit status proves nothing, since a random signal handler may
 * send it anywhere in its own code.  Prints the seed and batch on the
 * first difference and exits 1; prints "fzsys ok" otherwise.
 */

#include <stdio.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	NCALL	300
#define	BUFSZ	8192
#define	FUZZUID	8
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
int	batch, ncall = NCALL, safe;
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

/*
 * May call n be made?  fork, exec, and exit never; with -s, nothing
 * which could create, write, remove, or change a file on the disk,
 * nor brk, which could grow a child past the RAM and so swap it to
 * the disk, and neither signal nor sigreturn, since a random handler
 * or frame could send the child to the svc in rawsys with any number
 * in r7.
 */
static int
allowed(int n)
{
	static char unsafe[] = { 8, 9, 10, 12, 14, 15, 16, 17, 21, 22, 30, 36,
		42, 48, 51, 61, 63, 0 };
	char *p;

	n &= 077;
	if(n == 1 || n == 2 || n == 11 || n == 59)
		return(0);
	if(safe)
		for(p = unsafe; *p; p++)
			if(*p == n)
				return(0);
	return(1);
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
	chdir(safe ? "/" : "/tmp/fz/sys");
	for(i = 0; i < BUFSZ; i++)
		buf[i] = rnd(256);
	for(i = 0; i < (int)sizeof(longname)-1; i++)
		longname[i] = 'a' + i%26;
	for(i = 0; i < ncall; i++) {
		do
			n = rnd(70);
		while(!allowed(n));
		rawsys(n, arg(), arg(), arg(), arg());
		if(creat(PROOF, 0644) >= 0)
			exit(8);
	}
	exit(0);
}

/*
 * Kill every process of uid, the strays of a batch: a child sent by a
 * random signal handler into this program's own code may fork.  The
 * kernel lets a process of uid signal only processes of uid.
 */
static void
reap(int uid)
{
	int pid, me, w, status;

	if((pid = fork()) == 0) {
		if(setuid(uid) < 0)
			exit(1);
		me = getpid();
		for(w = 2; w < 30000; w++)
			if(w != me)
				kill(w, SIGKILL);
		exit(0);
	}
	while((w = wait(&status)) != pid && w >= 0)
		;
}

static int
same(struct stat *a, struct stat *b)
{
	return(a->st_ino == b->st_ino && a->st_mode == b->st_mode &&
	    a->st_uid == b->st_uid && a->st_size == b->st_size &&
	    a->st_mtime == b->st_mtime);
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
	int i, nbatch, first, pid, w, status;

	if(argc > 1 && strcmp(argv[1], "-s") == 0) {
		safe = 1;
		argc--;
		argv++;
	}
	if(argc < 3 || argc > 5) {
		printf("usage: fzsys [-s] seed batches [first [calls]]\n");
		exit(2);
	}
	seed = atol(argv[1]);
	nbatch = atoi(argv[2]);
	first = argc >= 4 ? atoi(argv[3]) : 0;
	if(argc == 5)
		ncall = atoi(argv[4]);
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
		fail("cannot become uid 8");
	for(batch = first; batch < nbatch; batch++) {
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
		reap(FUZZUID);
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
