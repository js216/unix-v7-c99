/* Ported from v7/usr/src/libc/stdio/getpwnam.c.
 * K&R prototype -> C99, register dropped. Algorithm unchanged. */
#include "u.h"
#include <pwd.h>

struct passwd *
getpwnam(char *name)
{
	struct passwd *p;

	setpwent();
	while((p = getpwent()) && strcmp(name, p->pw_name))
		;
	endpwent();
	return(p);
}
