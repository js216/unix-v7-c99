#include "stdio.h"
#include "lrndef"
#include "lrnref"
#include "signal.h"

extern void selsub(int, char **);
extern void selunit(void);
extern void dounit(void);
extern void whatnow(void);
extern void wrapup(int);

void hangup(int);
void intrpt(int);

int
main(int argc, char *argv[])
{
	extern char *getlogin(void);
	extern char *malloc(unsigned);

	speed = 0;
	more = 1;
	pwline = getlogin();
	setbuf(stdout, malloc(BUFSIZ));
	selsub(argc, argv);
	signal(SIGHUP, hangup);
	signal(SIGINT, intrpt);
	while (more) {
		selunit();
		dounit();
		whatnow();
	}
	wrapup(0);
	return 0;
}

void
hangup(int sig)
{
	(void)sig;
	wrapup(1);
}

void
intrpt(int sig)
{
	char response[20], *p;
	(void)sig;

	signal(SIGINT, hangup);
	write(2, "\nInterrupt.\nWant to go on?  ", 28);
	p = response;
	*p = 'n';
	while (read(0, p, 1) == 1 && *p != '\n')
		p++;
	if (response[0] != 'y')
		wrapup(1);
	ungetc('\n', stdin);
	signal(SIGINT, intrpt);
}
