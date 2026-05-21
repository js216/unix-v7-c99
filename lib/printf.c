#include	<stdio.h>
#include	<stdarg.h>
extern void _doprnt(char *fmt, va_list *adx, FILE *file);

int
printf(char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	_doprnt(fmt, &ap, stdout);
	va_end(ap);
	return(ferror(stdout)? EOF: 0);
}
