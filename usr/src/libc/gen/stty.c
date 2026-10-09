/*
 * Writearound to old stty and gtty system calls
 */

#include <stdio.h>
#include <sgtty.h>

int
stty(int fd, struct sgttyb *ap)
{
	return(ioctl(fd, TIOCSETP, ap));
}

int
gtty(int fd, struct sgttyb *ap)
{
	return(ioctl(fd, TIOCGETP, ap));
}
