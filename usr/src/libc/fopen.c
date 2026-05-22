#include	<stdio.h>

FILE *
fopen(char *file, char *mode)
{
	FILE *_findiop(void);
	FILE *_endopen(char *file, char *mode, register FILE *iop);

	return(_endopen(file, mode, _findiop()));
}
