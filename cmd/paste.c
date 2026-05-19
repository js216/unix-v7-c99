/* paste -- merge corresponding lines from multiple files side-by-side
 * joined by TAB.  V7 didn't ship paste; this is the minimal form
 * (paste file1 [file2...]).  No -d, no -s. */

#include <stdio.h>

int
main(int argc, char *argv[])
{
	FILE *fp[16];
	int nf, i, c;
	int active;

	if (argc < 2) {
		fprintf(stderr, "usage: paste file [file...]\n");
		exit(1);
	}
	if (argc - 1 > (int)(sizeof(fp)/sizeof(fp[0]))) {
		fprintf(stderr, "paste: too many files\n");
		exit(1);
	}
	nf = 0;
	for (i = 1; i < argc; i++) {
		if ((fp[nf] = fopen(argv[i], "r")) == NULL) {
			fprintf(stderr, "paste: %s: cannot open\n", argv[i]);
			exit(1);
		}
		nf++;
	}
	{
		/* Buffer one row at a time -- emit only if anything got read.
		 * Avoids the trailing empty row when all inputs hit EOF mid-row. */
		char row[4096];
		int rn;
		for (;;) {
			active = 0;
			rn = 0;
			for (i = 0; i < nf; i++) {
				if (i > 0 && rn < (int)sizeof(row))
					row[rn++] = '\t';
				if (fp[i] == NULL)
					continue;
				c = getc(fp[i]);
				if (c == EOF) {
					fclose(fp[i]);
					fp[i] = NULL;
					continue;
				}
				active = 1;
				while (c != EOF && c != '\n') {
					if (rn < (int)sizeof(row))
						row[rn++] = (char)c;
					c = getc(fp[i]);
				}
				if (c == EOF) {
					fclose(fp[i]);
					fp[i] = NULL;
				}
			}
			if (!active)
				break;
			row[rn++] = '\n';
			fwrite(row, 1, rn, stdout);
		}
	}
	exit(0);
}
