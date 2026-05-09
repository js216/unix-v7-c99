/*
 * Print the error indicated in errno.
 *
 * Ported from v7/usr/src/libc/gen/perror.c.  K&R prototype -> C99,
 * register dropped, void return on the error path, void casts on
 * write() returns.  v7's `int errno; int sys_nerr; char *sys_errlist[];`
 * tentative definitions stay -- the linker coalesces them with any
 * other definition (errlst.c provides the table).
 */

int	errno;
int	sys_nerr;
/* sys_errlist is properly declared in v7 (incomplete array; the
 * full table lives in errlst.c).  C99 with -Werror=no-incomplete
 * objects to that, so size as 1 -- the linker coalesces tentative
 * definitions under -fcommon. */
char	*sys_errlist[1];

extern int strlen(char *);
extern int write(int, char *, int);

void
perror(char *s)
{
	char *c;
	int n;

	c = "Unknown error";
	if(errno < sys_nerr)
		c = sys_errlist[errno];
	n = strlen(s);
	if(n) {
		(void)write(2, s, n);
		(void)write(2, ": ", 2);
	}
	(void)write(2, c, strlen(c));
	(void)write(2, "\n", 1);
}
