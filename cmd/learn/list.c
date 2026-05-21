#include "stdio.h"
#include "lrnref"
#include "signal.h"

extern void intrpt(int);
void stop(int);

int istop;

void
list(char *r)
{
	FILE *ft;
	char s[100];

	if (r==0)
		return;
	istop = 1;
	signal(SIGINT, stop);
	ft = fopen(r, "r");
	if (ft != NULL) {
		while (fgets(s, 100, ft) && istop)
			fputs(s, stdout);
		fclose(ft);
	}
	signal(SIGINT, intrpt);
}

void
stop(int sig)
{
	(void)sig;
	istop=0;
}
