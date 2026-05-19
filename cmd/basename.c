#include	"stdio.h"

int
main(int argc, char *argv[])
{
	register char *p1, *p2, *p3;

	if (argc < 2) {
		putchar('\n');
		exit(1);
	}
	p1 = argv[1];
	p2 = p1;
	while (*p1) {
		if (*p1++ == '/')
			p2 = p1;
	}
	if (argc>2) {
		/* p1 points just past the basename's last char; p3 just past
		 * the suffix's last char.  Walk both backwards in lockstep;
		 * if every suffix char matches AND we reach the start of the
		 * suffix string before running out of basename, strip it. */
		for(p3=argv[2]; *p3; p3++)
			;
		while(p1>p2 && p3>argv[2])
			if(*--p3 != *--p1)
				goto output;
		/* If p3 reached argv[2], the whole suffix matched -> strip.
		 * Otherwise the basename was shorter than the suffix (loop
		 * exited because p1==p2) -- leave it intact. */
		if (p3 == argv[2])
			*p1 = '\0';
	}
output:
	puts(p2, stdout);
	exit(0);
}
