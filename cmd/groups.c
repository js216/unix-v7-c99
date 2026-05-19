/* groups [USER] -- print the group(s) USER belongs to (just the
 * primary group, since v7 has no /etc/group secondary memberships
 * structure for arbitrary listing in this port).  Without USER, uses
 * the current effective uid via getlogin()/getpwuid. */

#include <stdio.h>
#include <pwd.h>
#include <grp.h>

extern int getgid(void), getuid(void);
extern char *getlogin(void);
extern struct passwd *getpwnam(char *);
extern struct passwd *getpwuid(int);
extern struct group *getgrgid(int);

int
main(int argc, char *argv[])
{
	struct passwd *pw;
	struct group *gr;
	int gid;

	if (argc < 2) {
		pw = getpwuid(getuid());
		if (pw == 0) gid = getgid();
		else gid = pw->pw_gid;
	} else {
		pw = getpwnam(argv[1]);
		if (pw == 0) {
			fprintf(stderr, "groups: %s: no such user\n", argv[1]);
			exit(1);
		}
		gid = pw->pw_gid;
	}
	gr = getgrgid(gid);
	if (gr) puts(gr->gr_name);
	else    printf("%d\n", gid);
	exit(0);
}
