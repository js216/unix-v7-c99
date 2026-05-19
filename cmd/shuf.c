/* shuf -- random permutation of input lines.
 * Reads stdin (or FILE if given), shuffles lines via Fisher-Yates,
 * writes to stdout.  Uses v7's rand(3); seed from time(2).
 * -n N : print at most N lines.  -e ARGS : treat each ARG as a line.
 */

#include <stdio.h>
extern int rand(void);
extern void srand(unsigned int);

#define MAXLINES 4096
#define POOLSIZE (128 * 1024)

static char *lines[MAXLINES];
static int nlines;
static char pool[POOLSIZE];
static int pi;

static char *
xput(char *s, int n)
{
	char *out;
	int i;
	if (pi + n + 1 > (int)sizeof(pool)) return (char *)0;
	out = &pool[pi];
	for (i = 0; i < n; i++) out[i] = s[i];
	out[n] = '\0';
	pi += n + 1;
	return out;
}

static void
load_from(FILE *fp)
{
	char buf[1024];
	int len = 0, c;
	while ((c = getc(fp)) != EOF) {
		if (c == '\n') {
			if (nlines < MAXLINES) {
				lines[nlines] = xput(buf, len);
				if (lines[nlines]) nlines++;
			}
			len = 0;
		} else if (len < (int)sizeof(buf) - 1) {
			buf[len++] = (char)c;
		}
	}
	if (len > 0 && nlines < MAXLINES) {
		lines[nlines] = xput(buf, len);
		if (lines[nlines]) nlines++;
	}
}

int
main(int argc, char *argv[])
{
	int i, j, n = -1, start = 1;
	int eflag = 0;
	long t;
	char *tmp;
	FILE *fp;

	while (start < argc && argv[start][0] == '-' && argv[start][1] != '\0') {
		if (argv[start][1] == 'n' && argv[start][2] == '\0' && start + 1 < argc) {
			n = atoi(argv[start + 1]);
			start += 2;
		} else if (argv[start][1] == 'e' && argv[start][2] == '\0') {
			eflag = 1;
			start++;
			break;
		} else break;
	}

	time(&t);
	srand((unsigned int)t ^ (unsigned int)getpid());

	if (eflag) {
		for (i = start; i < argc; i++)
			if (nlines < MAXLINES) {
				int len = 0;
				while (argv[i][len]) len++;
				lines[nlines] = xput(argv[i], len);
				if (lines[nlines]) nlines++;
			}
	} else if (start >= argc) {
		load_from(stdin);
	} else {
		for (i = start; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "shuf: %s: cannot open\n", argv[i]);
				continue;
			}
			load_from(fp);
			fclose(fp);
		}
	}

	/* Fisher-Yates */
	for (i = nlines - 1; i > 0; i--) {
		j = (rand() & 0x7fffffff) % (i + 1);
		tmp = lines[i]; lines[i] = lines[j]; lines[j] = tmp;
	}

	if (n < 0 || n > nlines) n = nlines;
	for (i = 0; i < n; i++)
		printf("%s\n", lines[i]);
	exit(0);
}
