#include	<stdio.h>
#include	<stdarg.h>
int	_doscan(FILE *iop, char *fmt, va_list *argp);

int
scanf(char *fmt, ...)
{
	va_list args;
	int r;
	va_start(args, fmt);
	r = _doscan(stdin, fmt, &args);
	va_end(args);
	return(r);
}

int
fscanf(FILE *iop, char *fmt, ...)
{
	va_list args;
	int r;
	va_start(args, fmt);
	r = _doscan(iop, fmt, &args);
	va_end(args);
	return(r);
}

int
sscanf(register char *str, char *fmt, ...)
{
	va_list args;
	int r;
	FILE _strbuf;

	_strbuf._flag = _IOREAD|_IOSTRG;
	_strbuf._ptr = _strbuf._base = str;
	_strbuf._cnt = 0;
	while (*str++)
		_strbuf._cnt++;
	va_start(args, fmt);
	r = _doscan(&_strbuf, fmt, &args);
	va_end(args);
	return(r);
}
