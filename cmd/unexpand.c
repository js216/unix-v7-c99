/* unexpand -- convert leading runs of spaces to tabs.  V7 didn't ship
 * one; minimal form processes stdin or files, converts only leading
 * whitespace by default (POSIX `unexpand`).  TAB stop is 8. */

#include <stdio.h>

#define TABSTOP 8

static void
flush_spaces(int n, int col, int leading)
{
	int target = col + n;
	if (!leading) {
		while (n--) putchar(' ');
		return;
	}
	while (col + TABSTOP - (col % TABSTOP) <= target) {
		int gap = TABSTOP - (col % TABSTOP);
		putchar('\t');
		col += gap;
		n -= gap;
	}
	while (n-- > 0)
		putchar(' ');
}

static void
process(FILE *fp)
{
	int c, col = 0, pending = 0, leading = 1;

	while ((c = getc(fp)) != EOF) {
		if (c == ' ') {
			pending++;
			continue;
		}
		if (pending) {
			flush_spaces(pending, col, leading);
			col += pending;
			pending = 0;
		}
		if (c == '\t') {
			putchar('\t');
			col += TABSTOP - (col % TABSTOP);
		} else if (c == '\n') {
			putchar('\n');
			col = 0;
			leading = 1;
		} else {
			putchar(c);
			col++;
			leading = 0;
		}
	}
	if (pending) {
		flush_spaces(pending, col, leading);
	}
}

int
main(int argc, char *argv[])
{
	int i;
	FILE *fp;

	if (argc == 1) {
		process(stdin);
	} else {
		for (i = 1; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "unexpand: %s: cannot open\n", argv[i]);
				continue;
			}
			process(fp);
			fclose(fp);
		}
	}
	exit(0);
}
