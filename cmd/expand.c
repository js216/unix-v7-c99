/* expand -- convert tabs to spaces.  V7 didn't ship expand; reads
 * stdin or named files, every TAB advances output to the next
 * multiple of TABSTOP columns.  Default TABSTOP=8.  `-N` selects a
 * different fixed stop. */

#include <stdio.h>

static int tabstop = 8;

static void
process(FILE *fp)
{
	int c, col = 0, fill;

	while ((c = getc(fp)) != EOF) {
		if (c == '\t') {
			fill = tabstop - (col % tabstop);
			while (fill-- > 0) {
				putchar(' ');
				col++;
			}
		} else if (c == '\n') {
			putchar(c);
			col = 0;
		} else if (c == '\b') {
			putchar(c);
			if (col > 0) col--;
		} else {
			putchar(c);
			col++;
		}
	}
}

int
main(int argc, char *argv[])
{
	int i, start = 1;
	FILE *fp;

	if (argc > 1 && argv[1][0] == '-' && argv[1][1] >= '0' && argv[1][1] <= '9') {
		char *p = argv[1] + 1;
		int v = 0;
		while (*p >= '0' && *p <= '9') {
			v = v * 10 + (*p++ - '0');
		}
		if (v > 0) tabstop = v;
		start = 2;
	}
	if (start >= argc) {
		process(stdin);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "expand: %s: cannot open\n", argv[i]);
				continue;
			}
			process(fp);
			fclose(fp);
		}
	}
	exit(0);
}
