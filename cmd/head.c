/* head -- print first N lines (or -c bytes) of files (or stdin).
 * V7 didn't ship a head(1); this is a minimal fill-in so common
 * pipelines like `... | head -3` and `... | head -c 100` work.
 * Defaults: -10 lines.  Multiple file args get a banner. */

#include <stdio.h>

int
main(int argc, char *argv[])
{
	int n = 10, c, lines, i, start = 1, multi;
	int byte_mode = 0;
	FILE *fp;

	if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'c') {
		char *p = argv[1] + 2;
		int v = 0;
		if (*p == '\0' && start + 1 < argc) {
			p = argv[++start];
		}
		while (*p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
		if (v > 0) n = v;
		byte_mode = 1;
		start++;
	} else if (argc > 1 && argv[1][0] == '-') {
		char *p = argv[1] + 1;
		int v = 0;
		while (*p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
		if (v > 0) n = v;
		start = 2;
	}
	multi = (argc - start) > 1;
	if (start >= argc) {
		lines = 0;
		while ((c = getchar()) != EOF) {
			putchar(c);
			if (byte_mode) {
				if (++lines >= n) break;
			} else if (c == '\n' && ++lines >= n) {
				break;
			}
		}
		exit(0);
	}
	for (i = start; i < argc; i++) {
		if ((fp = fopen(argv[i], "r")) == NULL) {
			fprintf(stderr, "head: %s: cannot open\n", argv[i]);
			continue;
		}
		if (multi)
			printf("==> %s <==\n", argv[i]);
		lines = 0;
		while ((c = getc(fp)) != EOF) {
			putchar(c);
			if (byte_mode) {
				if (++lines >= n) break;
			} else if (c == '\n' && ++lines >= n) {
				break;
			}
		}
		fclose(fp);
	}
	exit(0);
}
