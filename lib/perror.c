/*
 * Print the error indicated
 * in the cerror cell.
 */
#include <stdio.h>

int	errno;
int	sys_nerr;
char	*sys_errlist[1];
void
perror(s)
char *s;
{
	register char *c;
	register int n;

	c = "Unknown error";
	if(errno < sys_nerr)
		c = sys_errlist[errno];
	n = strlen(s);
	if(n) {
		write(2, s, n);
		write(2, ": ", 2);
	}
	write(2, c, strlen(c));
	write(2, "\n", 1);
}
