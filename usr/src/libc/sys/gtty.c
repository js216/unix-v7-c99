#include <sgtty.h>
int ioctl(int, int, char *);
int
gtty(int fd, struct sgttyb *ap)
{
	return(ioctl(fd, TIOCGETP, (char *)ap));
}
