/*
 * fzelf seed tries: exec mutated programs.  Each try copies a valid
 * program, changes a few of its bytes, mostly in the ELF header and
 * the program headers, where the kernel decides how to load it,
 * sometimes truncates it, and executes it as uid 9, its own, with its
 * standard files on /dev/null, in /tmp/fz/elf.  The exec may fail,
 * the program may run or die, but the kernel must not panic, no
 * file of the system may change, and the try must end.  Prints the
 * seed and try on the first difference and exits 1; prints
 * "fzelf ok" otherwise.
 */

#include <stdio.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

#define	BASE	"/usr/local/test/utils/fzgen"
#define	MAXF	65536
#define	FUZZUID	9
#define	FUZZGID	3

char	orig[MAXF], img[MAXF];
int	norig;
unsigned long	rs;
long	seed;
int	try;
struct	stat	sunix, ssh;

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
	printf("FAIL fzelf seed %ld try %d: %s\n", seed, try, what);
	exit(1);
}

static void
put4(int o, unsigned v)
{
	if(o >= 0 && o+4 <= norig) {
		img[o] = v;
		img[o+1] = v >> 8;
		img[o+2] = v >> 16;
		img[o+3] = v >> 24;
	}
}

/*
 * Change a few bytes: most in the first 52 bytes, the ELF header,
 * or in the program headers which follow it at 52, 32 bytes each.
 */
static int
mutate(void)
{
	static unsigned edge[] = {
		0, 1, 2, 0x7fffffff, 0x80000000, 0xffffffff, 0xc0000000,
		0xbffff000, 0x1000, 0x8000, 0xfff, 0x10000000, 4096, 52, 32,
	};
	int i, n, o, len;

	for(i = 0; i < norig; i++)
		img[i] = orig[i];
	len = norig;
	n = 1 + rnd(4);
	while(n-- > 0)
		switch(rnd(6)) {
		case 0:
			img[rnd(52)] = rnd(256);
			break;
		case 1:
			put4(4*rnd(13), edge[rnd(sizeof(edge)/sizeof(edge[0]))]);
			break;
		case 2:
		case 3:
			o = 52 + 32*rnd(3) + 4*rnd(8);
			put4(o, rnd(2) ? edge[rnd(sizeof(edge)/sizeof(edge[0]))] :
			    rnd(0));
			break;
		case 4:
			img[rnd(norig)] = rnd(256);
			break;
		default:
			if(rnd(3) == 0)
				len = rnd(norig);
		}
	return(len);
}

static void
child(void)
{
	int fd;

	for(fd = 0; fd < 20; fd++)
		close(fd);
	open("/dev/null", 2);
	dup(0);
	dup(0);
	if(setgid(FUZZGID) < 0 || setuid(FUZZUID) < 0)
		exit(9);
	alarm(2);
	execl("x", "x", "1", "lines", "3", (char *)0);
	exit(99);
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

static void
timeout(int sig)
{
	(void)sig;
}

int
main(int argc, char **argv)
{
	struct stat st;
	int fd, ntry, len, pid, w, status;

	if(argc != 3) {
		printf("usage: fzelf seed tries\n");
		exit(2);
	}
	seed = atol(argv[1]);
	ntry = atoi(argv[2]);
	rs = seed*2654435761UL + 5;
	if((fd = open(BASE, 0)) < 0 || (norig = read(fd, orig, MAXF)) <= 0 ||
	    norig == MAXF)
		fail("cannot read the base program");
	close(fd);
	if(chdir("/tmp/fz/elf") < 0 || stat("/unix", &sunix) < 0 ||
	    stat("/bin/sh", &ssh) < 0)
		fail("setup");
	for(try = 0; try < ntry; try++) {
		len = mutate();
		unlink("x");
		errno = 0;
		if((fd = creat("x", 0755)) < 0 || write(fd, img, len) != len) {
			if(errno != ENOSPC)
				fail("write x");
			close(fd);
			sleep(1);
			continue;
		}
		close(fd);
		if((pid = fork()) < 0)
			fail("fork");
		if(pid == 0)
			child();
		signal(SIGALRM, timeout);
		alarm(4);
		while((w = wait(&status)) != pid)
			if(w < 0)
				kill(pid, SIGKILL);
		alarm(0);
		reap(FUZZUID);
		if(stat("/unix", &st) < 0 || st.st_mtime != sunix.st_mtime ||
		    st.st_size != sunix.st_size || stat("/bin/sh", &st) < 0 ||
		    st.st_mtime != ssh.st_mtime)
			fail("a system file changed");
	}
	unlink("x");
	printf("fzelf ok\n");
	exit(0);
}
