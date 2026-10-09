#include <grp.h>

struct group *
getgrgid(register int gid)
{
	register struct group *p;

	setgrent();
	while( (p = getgrent()) && p->gr_gid != gid );
	endgrent();
	return(p);
}
