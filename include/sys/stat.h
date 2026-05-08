#ifndef SYS_STAT_H
#define SYS_STAT_H
#include <sys/types.h>

struct	stat
{
	dev_t	st_dev;
	ino_t	st_ino;
	unsigned short st_mode;
	short	st_nlink;
	short	st_uid;
	short	st_gid;
	dev_t	st_rdev;
	off_t	st_size;
	time_t	st_atime;
	time_t	st_mtime;
	time_t	st_ctime;
};

#define	S_IFMT	0170000
#define		S_IFDIR	0040000
#define		S_IFCHR	0020000
#define		S_IFBLK	0060000
#define		S_IFREG	0100000
#define	S_IREAD	0000400
#define	S_IWRITE	0000200
#define	S_IEXEC	0000100
#endif
