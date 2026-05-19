/*
 * Update the file system every 30 seconds.
 * For cache benefit, open certain system directories.
 */

#include <stdio.h>
#include <signal.h>

int	dosync(void);

char *fillst[] = {
	"/bin",
	"/usr",
	"/usr/bin",
	0,
};

int
main(void)
{
	char **f;

	if(fork())
		exit(0);
	close(0);
	close(1);
	close(2);
	for(f = fillst; *f; f++)
		open(*f, 0);
	dosync();
	for(;;)
		pause();
}

int
dosync(void)
{
	sync();
	signal(SIGALRM, (int)dosync);
	alarm(30);
	return(0);
}
