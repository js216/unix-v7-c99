#include	<stdio.h>

FILE *
fopen(char *file, char *mode)
{
	return(_endopen(file, mode, _findiop()));
}
