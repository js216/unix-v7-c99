/* column -- format lines into a multi-column display.  Reads stdin
 * and arranges entries to fit within COLS columns (default 80), with
 * each cell padded to the longest entry width.  Default fill order is
 * down-then-right (like ls).  -x reverses to across-then-down. */

#include <stdio.h>

#define MAXLINES 1024
#define LINEBUF 256
#define POOLSIZE (64 * 1024)

static char *lines[MAXLINES];
static int nlines;
static int xflag;
static int width = 80;

static char *
xstrdup(char *s, int n)
{
	static char pool[POOLSIZE];
	static int pi;
	char *out;
	int i;
	if (pi + n + 1 > (int)sizeof(pool)) return (char *)0;
	out = &pool[pi];
	for (i = 0; i < n; i++) out[i] = s[i];
	out[n] = '\0';
	pi += n + 1;
	return out;
}

int
main(int argc, char *argv[])
{
	char buf[LINEBUF];
	int c, i, j, len = 0, longest = 0;
	int ncols, nrows, idx;
	int start = 1;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 'x' && argv[start][2] == '\0') {
			xflag = 1; start++;
		} else if (argv[start][1] == 'c' && argv[start][2] == '\0' &&
		           start + 1 < argc) {
			width = atoi(argv[start + 1]);
			if (width <= 0) width = 80;
			start += 2;
		} else break;
	}

	while ((c = getchar()) != EOF) {
		if (c == '\n') {
			buf[len] = '\0';
			if (len > 0 && nlines < MAXLINES) {
				lines[nlines++] = xstrdup(buf, len);
				if (lines[nlines-1] == 0) { nlines--; break; }
				if (len > longest) longest = len;
			}
			len = 0;
		} else if (len < LINEBUF - 1) {
			buf[len++] = (char)c;
		}
	}
	if (len > 0 && nlines < MAXLINES) {
		buf[len] = '\0';
		lines[nlines++] = xstrdup(buf, len);
		if (lines[nlines-1] && len > longest) longest = len;
	}
	if (nlines == 0) exit(0);

	ncols = width / (longest + 2);
	if (ncols < 1) ncols = 1;
	nrows = (nlines + ncols - 1) / ncols;

	for (i = 0; i < nrows; i++) {
		for (j = 0; j < ncols; j++) {
			if (xflag) idx = i * ncols + j;
			else       idx = j * nrows + i;
			if (idx >= nlines) continue;
			fputs(lines[idx], stdout);
			if (j < ncols - 1) {
				int pad = (longest + 2) - 0;
				int slen = 0;
				char *p;
				for (p = lines[idx]; *p; p++) slen++;
				for (; slen < pad; slen++) putchar(' ');
			}
		}
		putchar('\n');
	}
	exit(0);
}
