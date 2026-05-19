/* fold -- wrap long lines to fit a column limit.  POSIX form:
 *   fold [-w WIDTH] [-s] [FILE...]
 * Default WIDTH is 80.  With -s, break at the last space before WIDTH
 * (word wrap) rather than mid-token. */

#include <stdio.h>

static int width = 80;
static int sflag;

static void
process(FILE *fp)
{
	int col = 0, c;
	char buf[1024];
	int bn = 0;	/* number of buffered chars on current logical line */
	int last_space = -1;

	while ((c = getc(fp)) != EOF) {
		if (c == '\n') {
			fwrite(buf, 1, bn, stdout);
			putchar('\n');
			bn = 0; col = 0; last_space = -1;
			continue;
		}
		/* Tab/backspace columns: simple handling. */
		if (bn < (int)sizeof(buf) - 1) buf[bn++] = (char)c;
		if (c == ' ' || c == '\t') last_space = bn - 1;
		col++;
		if (col >= width) {
			int brk = bn;
			if (sflag && last_space >= 0 && last_space < bn) {
				brk = last_space + 1;
			}
			fwrite(buf, 1, brk, stdout);
			putchar('\n');
			/* Carry over the tail. */
			{
				int rem = bn - brk;
				int i;
				for (i = 0; i < rem; i++) buf[i] = buf[brk + i];
				bn = rem;
			}
			col = bn;
			last_space = -1;
		}
	}
	if (bn > 0) {
		fwrite(buf, 1, bn, stdout);
		putchar('\n');
	}
}

int
main(int argc, char *argv[])
{
	int i, start = 1;
	FILE *fp;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 'w' && argv[start][2] == '\0' &&
		    start + 1 < argc) {
			width = atoi(argv[start + 1]);
			if (width <= 0) width = 80;
			start += 2;
		} else if (argv[start][1] == 's' && argv[start][2] == '\0') {
			sflag = 1;
			start++;
		} else break;
	}
	if (start >= argc) {
		process(stdin);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "fold: %s: cannot open\n", argv[i]);
				continue;
			}
			process(fp);
			fclose(fp);
		}
	}
	exit(0);
}
