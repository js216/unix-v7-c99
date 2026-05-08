#include "../lib/u.h"

static char name[32];

static void
getline(char *buf, int n)
{
	int i;
	char c;

	i = 0;
	while(i < n-1) {
		if(read(0, &c, 1) != 1)
			break;
		if(c == '\n')
			break;
		buf[i++] = c;
	}
	buf[i] = 0;
	puts("\n");
}

int
main(void)
{

	getline(name, sizeof(name));
	if(name[0] == 0)
		puts("root\n");
	else if(strcmp(name, "root") != 0)
		puts("login incorrect\n");
	(void)exec("/bin/sh");
	puts("login: no shell\n");
	return(1);
}
