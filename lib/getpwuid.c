#include <pwd.h>

struct passwd *
getpwuid(register int uid)
{
	register struct passwd *p;

	setpwent();
	while( (p = getpwent()) && p->pw_uid != uid );
	endpwent();
	return(p);
}
