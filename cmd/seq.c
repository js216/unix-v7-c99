/* seq -- print a sequence of integers.  V7 didn't ship seq(1); this
 * is the common BSD form: seq [-s SEP] [first [incr]] last.
 * Default first=1, incr=1, SEP="\n".  Integers only (no float).
 * Negative increments supported. */

#include <stdio.h>

extern long atol(char *);

static int
digits(long v)
{
	int n = 0;
	if (v < 0) { n++; v = -v; }
	if (v == 0) return 1;
	while (v > 0) { n++; v /= 10; }
	return n;
}

int
main(int argc, char *argv[])
{
	long first = 1, incr = 1, last;
	long n;
	char *sep = "\n";
	int start = 1;
	int printed = 0;
	int wflag = 0;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 's' && argv[start][2] == '\0' &&
		    start + 1 < argc) {
			sep = argv[start + 1];
			start += 2;
		} else if (argv[start][1] == 'w' && argv[start][2] == '\0') {
			wflag = 1;
			start++;
		} else break;
	}
	if (argc - start < 1) {
		fprintf(stderr, "usage: seq [-s SEP] [first [incr]] last\n");
		exit(1);
	}
	if (argc - start == 1) {
		last = atol(argv[start]);
	} else if (argc - start == 2) {
		first = atol(argv[start]);
		last = atol(argv[start + 1]);
	} else {
		first = atol(argv[start]);
		incr  = atol(argv[start + 1]);
		last  = atol(argv[start + 2]);
	}
	if (incr == 0) {
		fprintf(stderr, "seq: increment must be nonzero\n");
		exit(1);
	}
	{
		int width = 0;
		char fmt[16];
		if (wflag) {
			int d1 = digits(first), d2 = digits(last);
			width = d1 > d2 ? d1 : d2;
			sprintf(fmt, "%%0%dld", width);
		} else {
			fmt[0] = '%'; fmt[1] = 'l'; fmt[2] = 'd'; fmt[3] = '\0';
		}
		if (incr > 0)
			for (n = first; n <= last; n += incr) {
				if (printed) fputs(sep, stdout);
				printf(fmt, n);
				printed = 1;
			}
		else
			for (n = first; n >= last; n += incr) {
				if (printed) fputs(sep, stdout);
				printf(fmt, n);
				printed = 1;
			}
	}
	if (printed) putchar('\n');
	exit(0);
}
