/* whoami -- print the effective username.  V7 didn't ship it. */

#include <stdio.h>
#include <pwd.h>

extern int geteuid(void);
extern struct passwd *getpwuid(int uid);

int
main(int argc, char *argv[])
{
	int uid;
	struct passwd *pw;
	(void)argc; (void)argv;

	uid = geteuid();
	pw = getpwuid(uid);
	if (pw)
		printf("%s\n", pw->pw_name);
	else
		printf("%d\n", uid);
	exit(0);
}
