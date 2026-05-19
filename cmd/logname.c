/* logname -- print the login name from /etc/utmp.  Not in v7, but the
 * library's getlogin() already does the lookup. */

#include <stdio.h>
extern char *getlogin(void);

int
main(int argc, char *argv[])
{
	char *p;
	(void)argc; (void)argv;
	p = getlogin();
	if (p == 0 || *p == '\0') {
		fprintf(stderr, "logname: no login name\n");
		exit(1);
	}
	puts(p);
	exit(0);
}
