#ifndef ARM_H
#define ARM_H

#define KERNBASE	0x40000000U
#define USERBASE	0x00000000U
#define USERPHYS	0x41000000U
#define USERSIZE	0x00100000U
#define UENTRY		0x00010000U
#define USTACK		0x000f0000U

#define S_FORK		2
#define S_READ		3
#define S_WRITE		4
#define S_OPEN		5
#define S_CLOSE		6
#define S_WAIT		7
#define S_CREAT		8
#define	S_LINK		9
#define S_UNLINK	10
#define S_EXEC		11
#define	S_CHDIR		12
#define	S_MKNOD		14
#define	S_CHMOD		15
#define	S_CHOWN		16
#define	S_STAT		18
#define S_LSEEK		19
#define	S_FSTAT		28
#define	S_UTIME		30
#define	S_ACCESS	33
#define S_SYNC		36
#define S_DUP		41
#define	S_PIPE		42
#define S_EXIT		1
#define S_GETDENTS	141
#define	S_SPAWN		200

#define	UARGV		0x0000f000U
#define	UARGLEN		512

#endif
