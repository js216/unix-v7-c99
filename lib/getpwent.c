/* Ported from v7/usr/src/libc/stdio/getpwent.c.
 * K&R prototypes -> C99, register dropped, void return on
 * setpwent/endpwent. Algorithm and i/o sequence unchanged. */
#include "u.h"
#include <stdio.h>
#include <pwd.h>

extern int atoi(char *);

static char PASSWD[]	= "/etc/passwd";
static char EMPTY[] = "";
static FILE *pwf = NULL;
static char line[BUFSIZ+1];
static struct passwd passwd;

void
setpwent(void)
{
	if(pwf == NULL)
		pwf = fopen(PASSWD, "r");
	else
		rewind(pwf);
}

void
endpwent(void)
{
	if(pwf != NULL) {
		fclose(pwf);
		pwf = NULL;
	}
}

static char *
pwskip(char *p)
{
	while(*p && *p != ':')
		++p;
	if(*p) *p++ = 0;
	return(p);
}

struct passwd *
getpwent(void)
{
	char *p;

	if(pwf == NULL) {
		if((pwf = fopen(PASSWD, "r")) == NULL)
			return(0);
	}
	p = fgets(line, BUFSIZ, pwf);
	if(p == NULL)
		return(0);
	passwd.pw_name = p;
	p = pwskip(p);
	passwd.pw_passwd = p;
	p = pwskip(p);
	passwd.pw_uid = atoi(p);
	p = pwskip(p);
	passwd.pw_gid = atoi(p);
	passwd.pw_quota = 0;
	passwd.pw_comment = EMPTY;
	p = pwskip(p);
	passwd.pw_gecos = p;
	p = pwskip(p);
	passwd.pw_dir = p;
	p = pwskip(p);
	passwd.pw_shell = p;
	while(*p && *p != '\n') p++;
	*p = '\0';
	return(&passwd);
}
