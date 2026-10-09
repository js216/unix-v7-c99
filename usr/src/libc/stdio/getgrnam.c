#include <stdio.h>
#include <grp.h>

struct group *
getgrnam(register char *name)
{
	register struct group *p;
	struct group *getgrent();

	setgrent();
	while( (p = getgrent()) && strcmp(p->gr_name,name) );
	endgrent();
	return(p);
}
