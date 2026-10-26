/*
 * fzboard [seed]: the fuzzers which are safe for the board's SD card,
 * for ever.  Each round runs fzsys -s, held to calls which change no
 * file, beside fzmem, kept below the RAM so that nothing is swapped,
 * and fzlib, which writes no file, and prints "fuzz round N seeds S-T
 * done".  The loop is a program,
 * not a shell script, because the shell's `...` reads through a pipe,
 * whose data the disk would receive at the next sync.
 */

#include <stdio.h>

#define	U	"/usr/local/test/utils/"

static int
run(char *prog, char *a1, char *a2, char *a3, char *a4)
{
	int pid;

	if((pid = fork()) == 0) {
		execl(prog, prog, a1, a2, a3, a4, (char *)0);
		printf("fzboard: cannot run %s\n", prog);
		exit(1);
	}
	return(pid);
}

int
main(int argc, char **argv)
{
	char s1[20], s2[20], s3[20];
	long s, r;
	int status;

	s = argc > 1 ? atol(argv[1]) : 1;
	for(r = 1; ; r++) {
		sprintf(s1, "%ld", s);
		sprintf(s2, "%ld", s + 1);
		sprintf(s3, "%ld", s + 2);
		run(U "fzsys", "-s", s1, "40", (char *)0);
		run(U "fzmem", s2, "4", "30", (char *)0);
		run(U "fzlib", s3, "2", (char *)0, (char *)0);
		while(wait(&status) >= 0)
			;
		printf("fuzz round %ld seeds %ld-%ld done\n", r, s, s + 2);
		s += 3;
	}
}
