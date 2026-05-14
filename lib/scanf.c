#include	<stdio.h>
#include	<stdarg.h>
int	_doscan();

int
scanf(char *fmt, ...)
{
	va_list ap;
	int r;
	va_start(ap, fmt);
	r = _doscan(stdin, fmt, &ap);
	va_end(ap);
	return(r);
}

int
fscanf(FILE *iop, char *fmt, ...)
{
	va_list ap;
	int r;
	va_start(ap, fmt);
	r = _doscan(iop, fmt, &ap);
	va_end(ap);
	return(r);
}

int
sscanf(char *str, char *fmt, ...)
{
	FILE _strbuf;
	va_list ap;
	int r;

	_strbuf._flag = _IOREAD|_IOSTRG;
	_strbuf._ptr = _strbuf._base = str;
	_strbuf._cnt = 0;
	while (*str++)
		_strbuf._cnt++;
	va_start(ap, fmt);
	r = _doscan(&_strbuf, fmt, &ap);
	va_end(ap);
	return(r);
}
