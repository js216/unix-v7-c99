/* dirname -- print directory portion of a pathname.  V7 didn't ship
 * dirname(1); paired with v7's basename(1). */

#include <stdio.h>

int
main(int argc, char *argv[])
{
	char *p, *last;

	if (argc < 2) {
		fprintf(stderr, "usage: dirname path\n");
		exit(1);
	}
	p = argv[1];
	/* trim trailing slashes (except the leading "/") */
	{
		char *e = p;
		while (*e) e++;
		while (e > p+1 && e[-1] == '/') *--e = '\0';
	}
	last = (char *)0;
	for (char *q = p; *q; q++)
		if (*q == '/')
			last = q;
	if (last == (char *)0) {
		/* no slash: dirname is "." */
		printf(".\n");
	} else if (last == p) {
		/* only slash is at position 0: dirname is "/" */
		printf("/\n");
	} else {
		*last = '\0';
		printf("%s\n", p);
	}
	exit(0);
}
