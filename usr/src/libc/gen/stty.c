/*
 * Writearound to old stty and gtty system calls
 */

#include <stdio.h>
#include <sgtty.h>

int
stty(fd, ap)
int fd;
struct sgtty *ap;
{
	return(ioctl(fd, TIOCSETP, ap));
}

int
gtty(fd, ap)
int fd;
struct sgtty *ap;
{
	return(ioctl(fd, TIOCGETP, ap));
}
