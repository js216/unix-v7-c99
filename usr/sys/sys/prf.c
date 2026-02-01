#include "../h/param.h"
#include "../h/systm.h"
#include "../h/seg.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include <stdarg.h>

/*
 * In case console is off,
 * panicstr contains argument to last
 * call to panic.
 */
char	*panicstr;

/*
 * Print an unsigned integer in base b.
 */
void printn(long n, int b)
{
	long a;

	if (n<0) {	/* shouldn't happen */
		putchar('-');
		n = -n;
	}
	if((a = n/b))
		printn(a, b);
	putchar("0123456789ABCDEF"[(int)(n%b)]);
}

/*
 * Scaled down version of C Library printf.
 * Only %s %u %d (==%u) %o %x %D are recognized.
 * Used to print diagnostic information
 * directly on console tty.
 * Since it is not interrupt driven,
 * all system activities are pretty much
 * suspended.
 * Printf should not be used for chit-chat.
 */
/* VARARGS 1 */
void printf(char *fmt, ...)
{
	int c;
	va_list adx;
	char *s;

	va_start(adx, fmt);
loop:
	while((c = *fmt++) != '%') {
		if(c == '\0') {
		   va_end(adx);
			return;
		}
		putchar(c);
	}
	c = *fmt++;
	if(c == 'd' || c == 'u' || c == 'o' || c == 'x')
		printn((long)va_arg(adx, unsigned), c=='o'? 8: (c=='x'? 16:10));
	else if(c == 's') {
		s = va_arg(adx, char*);
		while((c = *s++))
			putchar(c);
	} else if (c == 'D')
		printn(va_arg(adx, long), 10);
	goto loop;
}

/*
 * Panic is called on unresolvable
 * fatal errors.
 * It syncs, prints "panic: mesg" and
 * then loops.
 */
void panic(char *s)
{
	panicstr = s;
	//update();
	printf("panic: %s\n", s);
	for(;;)
		;//idle();
}

/*
 * prdev prints a warning message of the
 * form "mesg on dev x/y".
 * x and y are the major and minor parts of
 * the device argument.
 */
void prdev(char *str, dev_t dev)
{
	printf("%s on dev %u/%u\n", str, major(dev), minor(dev));
}

/*
 * deverr prints a diagnostic from
 * a device driver.
 * It prints the device, block number,
 * and an octal word (usually some error
 * status register) passed as argument.
 */
void deverror(struct buf *bp, int o1, int o2)
{
	prdev("err", bp->b_dev);
	printf("bn=%D er=%o,%o\n", &bp->b_blkno, o1, o2);
}
