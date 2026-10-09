#include <stdio.h>
#include <pwd.h>

struct passwd *
getpwnam(char *name)
{
	register struct passwd *p;

	setpwent();
	while( (p = getpwent()) && strcmp(name,p->pw_name) );
	endpwent();
	return(p);
}
