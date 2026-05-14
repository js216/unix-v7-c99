#include <stdio.h>

int
fgetc(fp)
FILE *fp;
{
	return(getc(fp));
}
