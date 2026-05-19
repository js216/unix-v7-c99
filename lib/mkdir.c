/* mkdir(3) -- v7 has no mkdir(2) syscall, so this is the cmd/mkdir.c
 * recipe wrapped as a callable libc helper:  mknod (IFDIR | mode) on
 * the new path, then link target to its "." and parent to its ".."
 * Returns 0 on success, -1 on failure.  Only succeeds for root, since
 * mknod(2) is privileged. */

#include <stdio.h>
extern int mknod(char *path, int mode, int dev);
extern int link(char *old, char *new);
extern int unlink(char *path);
extern int access(char *path, int amode);
extern int chown(char *path, int uid, int gid);
extern int getuid(void);
extern int getgid(void);

int
mkdir(char *path, int mode)
{
	char pname[256], dname[256];
	int i, slash = 0;

	for (i = 0; path[i] && i < 250; i++) {
		pname[i] = path[i];
		if (path[i] == '/') slash = i + 1;
	}
	if (slash) {
		for (i = 0; i < slash; i++) pname[i] = path[i];
	} else {
		pname[0] = '\0';
		slash = 0;
	}
	pname[slash] = '.';
	pname[slash+1] = '\0';
	if (access(pname, 2) != 0) return -1;
	if (mknod(path, 040000 | (mode & 0777), 0) < 0) return -1;
	(void)chown(path, getuid(), getgid());
	for (i = 0; path[i] && i < 253; i++) dname[i] = path[i];
	dname[i++] = '/';
	dname[i++] = '.';
	dname[i] = '\0';
	if (link(path, dname) < 0) {
		(void)unlink(path);
		return -1;
	}
	dname[i++] = '.';
	dname[i] = '\0';
	if (link(pname, dname) < 0) {
		dname[i-1] = '\0';
		(void)unlink(dname);
		(void)unlink(path);
		return -1;
	}
	return 0;
}
