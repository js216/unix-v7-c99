/* nl -- number lines of files.  V7 didn't ship nl.  Supports the
 * common POSIX subset:
 *   -b a   number all lines (including blank)
 *   -b t   number only non-blank lines (default)
 *   -b n   number no lines
 * No section delimiters (-d, -f, -h) or pattern matching. */

#include <stdio.h>

static int bmode = 't';

static int
process(FILE *fp, int *lineno)
{
	int c, beginning = 1;
	long n = *lineno;
	int blank;

	for (;;) {
		c = getc(fp);
		if (c == EOF)
			return 0;
		blank = (c == '\n');
		if (beginning) {
			int do_num = 0;
			if (bmode == 'a') do_num = 1;
			else if (bmode == 't' && !blank) do_num = 1;
			if (do_num) printf("%6ld\t", n++);
			else        printf("      \t");
		}
		putchar(c);
		beginning = (c == '\n');
		if (beginning)
			*lineno = (int)n;
	}
}

int
main(int argc, char *argv[])
{
	int i, lineno = 1, start = 1;
	FILE *fp;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 'b' && start + 1 < argc) {
			bmode = argv[start + 1][0];
			start += 2;
		} else if (argv[start][1] == 'b' && argv[start][2] != '\0') {
			bmode = argv[start][2];
			start++;
		} else break;
	}

	if (start >= argc) {
		process(stdin, &lineno);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "nl: %s: cannot open\n", argv[i]);
				continue;
			}
			process(fp, &lineno);
			fclose(fp);
		}
	}
	exit(0);
}
