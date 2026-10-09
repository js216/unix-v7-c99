#include <stdio.h>

FILE *
freopen(char *file, char *mode, register FILE *iop)
{
	fclose(iop);
	return(_endopen(file, mode, iop));
}
