/* QEMU 'virt' PL011 UART Constants */
#define UART0_BASE 0x09000000
#define UART0_DR   *((volatile unsigned int *)(UART0_BASE + 0x00))
#define UART0_FR   *((volatile unsigned int *)(UART0_BASE + 0x18))

/* Flag Register Bit Masks */
#define TXFF (1 << 5)  /* Transmit FIFO Full */
#define RXFE (1 << 4)  /* Receive FIFO Empty */

void
putchar(char c)
{
	if(c == '\n')
		putchar('\r');
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
