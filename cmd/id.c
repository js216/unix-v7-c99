/* id -- print user id and group id.  V7 didn't ship id(1); this is
 * the minimal output expected of POSIX `id` for the common case. */

#include <stdio.h>
#include <pwd.h>

extern int getuid(void), geteuid(void), getgid(void), getegid(void);
extern struct passwd *getpwuid(int uid);

int
main(int argc, char *argv[])
{
	int uid, euid, gid, egid;
	struct passwd *pw;
	(void)argc; (void)argv;

	uid = getuid();
	euid = geteuid();
	gid = getgid();
	egid = getegid();
	pw = getpwuid(uid);
	printf("uid=%d", uid);
	if (pw) printf("(%s)", pw->pw_name);
	printf(" gid=%d", gid);
	if (uid != euid) {
		printf(" euid=%d", euid);
		pw = getpwuid(euid);
		if (pw) printf("(%s)", pw->pw_name);
	}
	if (gid != egid)
		printf(" egid=%d", egid);
	putchar('\n');
	exit(0);
}
