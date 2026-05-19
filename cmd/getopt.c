/* getopt -- parse command-line options for shell scripts.  Reads:
 *   getopt OPTSTRING ARG...
 * Prints a re-orderable form of ARGs where flags come first, each
 * separated by spaces, then `--`, then the positional args.  Flags
 * requiring values (chars in OPTSTRING followed by `:`) consume the
 * next arg.  Unrecognized flags print an error to stderr and exit 1. */

#include <stdio.h>

static int
has_arg(char *opts, int c)
{
	while (*opts) {
		if (*opts == c) return opts[1] == ':';
		opts++;
	}
	return -1;
}

int
main(int argc, char *argv[])
{
	char *opts;
	int i;

	if (argc < 2) {
		fprintf(stderr, "usage: getopt optstring args...\n");
		exit(2);
	}
	opts = argv[1];
	for (i = 2; i < argc; i++) {
		char *a = argv[i];
		int j;
		if (a[0] != '-' || a[1] == '\0') break;
		if (a[0] == '-' && a[1] == '-' && a[2] == '\0') { i++; break; }
		for (j = 1; a[j]; j++) {
			int kind = has_arg(opts, a[j]);
			if (kind < 0) {
				fprintf(stderr, "getopt: unknown option -%c\n", a[j]);
				exit(1);
			}
			printf("-%c ", a[j]);
			if (kind) {
				/* Argument may be glued (-fFILE) or in next arg. */
				if (a[j+1]) {
					printf("'%s' ", &a[j+1]);
					break;
				} else if (i + 1 < argc) {
					printf("'%s' ", argv[++i]);
					break;
				} else {
					fprintf(stderr, "getopt: -%c requires an argument\n", a[j]);
					exit(1);
				}
			}
		}
	}
	printf("--");
	for (; i < argc; i++)
		printf(" '%s'", argv[i]);
	printf("\n");
	exit(0);
}
