/* fmt -- simple paragraph reflower.  V7 didn't ship fmt.
 * Reads stdin (or files), breaks paragraphs (sequences of non-blank
 * lines) into lines of at most -w COLS columns (default 75), keeping
 * blank lines as paragraph separators. */

#include <stdio.h>

static int colwidth = 75;

static void
process(FILE *fp)
{
	char word[1024];
	int wn = 0;
	int col = 0;
	int c;
	int just_blank = 1;

	for (;;) {
		c = getc(fp);
		if (c == EOF || c == ' ' || c == '\t' || c == '\n') {
			if (wn > 0) {
				word[wn] = '\0';
				if (col == 0) {
					fputs(word, stdout);
					col = wn;
				} else if (col + 1 + wn <= colwidth) {
					putchar(' ');
					fputs(word, stdout);
					col += 1 + wn;
				} else {
					putchar('\n');
					fputs(word, stdout);
					col = wn;
				}
				wn = 0;
				just_blank = 0;
			}
			if (c == EOF) break;
			if (c == '\n') {
				/* Peek at next char to detect paragraph break */
				int n = getc(fp);
				if (n == '\n') {
					/* blank line -- flush current line, emit blank */
					if (col > 0) {
						putchar('\n');
						col = 0;
					}
					putchar('\n');
					just_blank = 1;
					/* consume any further blank lines */
					while ((n = getc(fp)) == '\n')
						;
					if (n == EOF) break;
					ungetc(n, fp);
				} else if (n == EOF) {
					break;
				} else {
					ungetc(n, fp);
				}
			}
			continue;
		}
		if (wn < (int)sizeof(word) - 1)
			word[wn++] = (char)c;
	}
	if (col > 0)
		putchar('\n');
	(void)just_blank;
}

int
main(int argc, char *argv[])
{
	int i, start = 1;
	FILE *fp;

	if (start < argc && argv[start][0] == '-' &&
	    argv[start][1] == 'w' && argv[start][2] == '\0' && start + 1 < argc) {
		char *p = argv[++start];
		int v = 0;
		while (*p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
		if (v > 0) colwidth = v;
		start++;
	}
	if (start >= argc) {
		process(stdin);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "fmt: %s: cannot open\n", argv[i]);
				continue;
			}
			process(fp);
			fclose(fp);
		}
	}
	exit(0);
}
