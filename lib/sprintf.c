#include	<stdio.h>
#include	<stdarg.h>
extern void _doprnt();

char *
sprintf(char *str, char *fmt, ...)
{
	struct _iobuf _strbuf;
	va_list ap;

	_strbuf._flag = _IOWRT+_IOSTRG;
	_strbuf._ptr = str;
	_strbuf._cnt = 32767;
	va_start(ap, fmt);
	_doprnt(fmt, &ap, &_strbuf);
	va_end(ap);
	putc('\0', &_strbuf);
	return(str);
}
