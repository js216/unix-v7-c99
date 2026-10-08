#include <stdio.h>
#include <grp.h>

struct group *
getgrnam(register char *name)
{
	register struct group *p;

	setgrent();
	while( (p = getgrent()) && strcmp(p->gr_name,name) );
	endgrent();
	return(p);
}
