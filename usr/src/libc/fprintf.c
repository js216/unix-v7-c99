#include	<stdio.h>
#include	<stdarg.h>
extern void _doprnt(char *fmt, va_list *adx, FILE *file);

int
fprintf(FILE *iop, char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	_doprnt(fmt, &ap, iop);
	va_end(ap);
	return(ferror(iop)? EOF: 0);
}
