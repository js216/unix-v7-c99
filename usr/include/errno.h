/*
 * Error codes -- ported from v7/usr/include/errno.h.
 * Numeric values are unchanged; these are the canonical V7 errnos
 * the ported libc relies on.
 */
#ifndef ERRNO_H
#define ERRNO_H

#define	EPERM	1
#define	ENOENT	2
#define	ESRCH	3
#define	EINTR	4
#define	EIO	5
#define	ENXIO	6
#define	E2BIG	7
#define	ENOEXEC	8
#define	EBADF	9
#define	ECHILD	10
#define	EAGAIN	11
#define	ENOMEM	12
#define	EACCES	13
#define	EFAULT	14
#define	ENOTBLK	15
#define	EBUSY	16
#define	EEXIST	17
#define	EXDEV	18
#define	ENODEV	19
#define	ENOTDIR	20
#define	EISDIR	21
#define	EINVAL	22
#define	ENFILE	23
#define	EMFILE	24
#define	ENOTTY	25
#define	ETXTBSY	26
#define	EFBIG	27
#define	ENOSPC	28
#define	ESPIPE	29
#define	EROFS	30
#define	EMLINK	31
#define	EPIPE	32

/* math software */
#define	EDOM	33
#define	ERANGE	34

extern int errno;

/* Port-side accommodation: several command sources include
 * <errno.h> and rely on it for the read/write/fstat/exit
 * syscall prototypes (a warts-and-all C99 build needs explicit
 * decls).  Kept here so we do not have to edit every
 * not-yet-converted-from-K&R command. */
struct stat;
int	read(int, char *, int);
int	write(int, char *, int);
int	open(char *, int);
int	close(int);
long	lseek(int, long, int);
int	fstat(int, struct stat *);
int	strlen(char *);
void	exit(int);

#endif
