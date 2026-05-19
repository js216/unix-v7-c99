/* cut -- extract fields/columns.  V7 didn't ship cut.
 *
 *   cut -c LIST [file...]    -- character ranges (1-based)
 *   cut -f LIST [-d C] [...] -- field ranges, delimiter C (default TAB)
 *
 * LIST is a comma-separated list of N, N-, -N, or N-M (1-based, inclusive).
 * Minimal subset; no -s/--complement. */

#include <stdio.h>

#define MAXRANGE 64

static int   nranges;
static int   lo[MAXRANGE], hi[MAXRANGE];	/* hi=0 means open-ended */

static void
parse_list(char *s)
{
	int a, b;
	nranges = 0;
	while (*s && nranges < MAXRANGE) {
		a = 0;
		while (*s >= '0' && *s <= '9') a = a * 10 + (*s++ - '0');
		if (*s == '-') {
			s++;
			b = 0;
			while (*s >= '0' && *s <= '9') b = b * 10 + (*s++ - '0');
			if (b == 0) b = -1;	/* open-ended */
			lo[nranges] = a > 0 ? a : 1;
			hi[nranges] = b;
		} else {
			lo[nranges] = a;
			hi[nranges] = a;
		}
		nranges++;
		if (*s == ',') s++;
	}
}

static int
in_range(int n)
{
	int i;
	for (i = 0; i < nranges; i++)
		if (n >= lo[i] && (hi[i] < 0 || n <= hi[i]))
			return 1;
	return 0;
}

static void
cut_chars(FILE *fp)
{
	int c, n = 0;
	while ((c = getc(fp)) != EOF) {
		if (c == '\n') {
			putchar(c);
			n = 0;
			continue;
		}
		n++;
		if (in_range(n))
			putchar(c);
	}
}

static void
cut_fields(FILE *fp, int delim)
{
	char buf[8192];
	int len = 0, c, had_line = 0;
	for (;;) {
		c = getc(fp);
		if (c == EOF || c == '\n') {
			if (c == EOF && len == 0)
				return;
			/* end of line: tokenize and emit selected fields */
			int i, fi = 1, first = 1, start = 0;
			int saw_delim = 0;
			for (i = 0; i <= len; i++)
				if (i == len || buf[i] == delim) {
					if (i == len && !saw_delim && fi == 1) {
						fwrite(buf, 1, len, stdout);
						break;
					}
					if (in_range(fi)) {
						if (!first)
							putchar(delim);
						fwrite(buf + start, 1, i - start, stdout);
						first = 0;
					}
					fi++;
					start = i + 1;
					if (i < len) saw_delim = 1;
				}
			putchar('\n');
			len = 0;
			had_line = 1;
			if (c == EOF) return;
			(void)had_line;
		} else {
			if (len < (int)sizeof(buf))
				buf[len++] = (char)c;
		}
	}
}

int
main(int argc, char *argv[])
{
	int mode = 0;	/* 0 unset, 1 chars, 2 fields */
	int delim = '\t';
	char *list = (char *)0;
	int i, start = 1;
	FILE *fp;

	while (start < argc && argv[start][0] == '-') {
		char *a = argv[start] + 1;
		if (*a == 'c') {
			mode = 1;
			a++;
			if (*a == '\0' && start + 1 < argc) list = argv[++start];
			else list = a;
		} else if (*a == 'f') {
			mode = 2;
			a++;
			if (*a == '\0' && start + 1 < argc) list = argv[++start];
			else list = a;
		} else if (*a == 'd') {
			a++;
			if (*a == '\0' && start + 1 < argc) a = argv[++start];
			delim = (unsigned char)*a;
		} else {
			fprintf(stderr, "usage: cut -c LIST | -f LIST [-d C] [file...]\n");
			exit(1);
		}
		start++;
	}
	if (!mode || !list) {
		fprintf(stderr, "usage: cut -c LIST | -f LIST [-d C] [file...]\n");
		exit(1);
	}
	parse_list(list);

	if (start >= argc) {
		if (mode == 1) cut_chars(stdin); else cut_fields(stdin, delim);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "cut: %s: cannot open\n", argv[i]);
				continue;
			}
			if (mode == 1) cut_chars(fp); else cut_fields(fp, delim);
			fclose(fp);
		}
	}
	exit(0);
}
