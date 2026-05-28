#define UART0_BASE 0x09000000
#define UART0_DR   *((volatile unsigned int *)(UART0_BASE + 0x00))
#define UART0_FR   *((volatile unsigned int *)(UART0_BASE + 0x18))

#define TXFF (1 << 5)
#define RXFE (1 << 4)

#define MSGBUFS	128
char	msgbuf[MSGBUFS];
char	*msgbufp = msgbuf;

void
putchar(char c)
{
	if(c == '\n')
		putchar('\r');
	c &= 0177;
	*msgbufp++ = c;
	if (msgbufp >= &msgbuf[MSGBUFS])
		msgbufp = msgbuf;
	while(UART0_FR & TXFF)
		;
	UART0_DR = c;
}

int
getchar(void)
{

	while(UART0_FR & RXFE)
		;
	return(UART0_DR & 0377);
}

int
getchar_ready(void)
{
	return (UART0_FR & RXFE) ? 0 : 1;
}
