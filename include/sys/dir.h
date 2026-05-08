#ifndef SYS_DIR_H
#define SYS_DIR_H
#include <sys/types.h>

#ifndef	DIRSIZ
#define	DIRSIZ	14
#endif
struct	direct
{
	ino_t	d_ino;
	char	d_name[DIRSIZ];
};
#endif
