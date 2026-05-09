/* Ported from v7/usr/src/libc/stdio/getpwuid.c.
 * K&R prototype -> C99, register dropped. */
#include "u.h"
#include <pwd.h>

struct passwd *
getpwuid(int uid)
{
	struct passwd *p;

	setpwent();
	while((p = getpwent()) && p->pw_uid != uid)
		;
	endpwent();
	return(p);
}
