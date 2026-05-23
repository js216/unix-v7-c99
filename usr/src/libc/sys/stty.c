
#include <sgtty.h>

int ioctl(int, int, char *);

int
stty(int fd, struct sgttyb *ap)
{
	return(ioctl(fd, TIOCSETP, (char *)ap));
}
