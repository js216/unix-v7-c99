/* tac -- reverse cat: print lines in reverse order.  V7 didn't ship
 * tac.  Reads all input into a buffer (capped), then prints lines
 * back-to-front. */

#include <stdio.h>

/* USERSIZE on our port is 1 MiB total (binary + stack + BSS), so a
 * 1 MiB static buf overflows into invalid memory.  256 KiB leaves
 * room for everything else and still handles typical scripts. */
#define MAXBUF 262144

static char buf[MAXBUF];

static void
dump(int len)
{
	int i, end;
	/* If the input ends with '\n' (normal POSIX text), trim it so the
	 * final line doesn't print as an extra blank row.  We re-add a
	 * newline after each emitted line anyway. */
	if (len > 0 && buf[len - 1] == '\n')
		len--;
	end = len;
	for (i = len - 1; i >= 0; i--) {
		if (buf[i] == '\n') {
			fwrite(buf + i + 1, 1, end - i - 1, stdout);
			putchar('\n');
			end = i;
		}
	}
	if (end > 0) {
		fwrite(buf, 1, end, stdout);
		putchar('\n');
	}
}

int
main(int argc, char *argv[])
{
	int len = 0, c, i;
	FILE *fp;

	if (argc == 1) {
		while ((c = getchar()) != EOF) {
			if (len < MAXBUF)
				buf[len++] = (char)c;
		}
		dump(len);
	} else {
		for (i = 1; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "tac: %s: cannot open\n", argv[i]);
				continue;
			}
			len = 0;
			while ((c = getc(fp)) != EOF) {
				if (len < MAXBUF)
					buf[len++] = (char)c;
			}
			dump(len);
			fclose(fp);
		}
	}
	exit(0);
}
