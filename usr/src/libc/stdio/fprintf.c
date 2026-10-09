#include	<stdio.h>
#include	<stdarg.h>
void	_doprnt(char *fmt, va_list *argp, FILE *iop);

int
fprintf(FILE *iop, char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	_doprnt(fmt, &args, iop);
	va_end(args);
	return(ferror(iop)? EOF: 0);
}
