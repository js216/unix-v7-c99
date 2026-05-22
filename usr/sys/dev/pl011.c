/* QEMU 'virt' PL011 UART Constants */
#define UART0_BASE 0x09000000
#define UART0_DR   *((volatile unsigned int *)(UART0_BASE + 0x00))
#define UART0_FR   *((volatile unsigned int *)(UART0_BASE + 0x18))

/* Flag Register Bit Masks */
#define TXFF (1 << 5)  /* Transmit FIFO Full */
#define RXFE (1 << 4)  /* Receive FIFO Empty */

/* v7-style kernel message-buffer ring.  The storage lives in
 * sys/dev/msgbuf.c (msgbuf[MSGBUFS] is declared tentatively by
 * h/systm.h; msgbufp is allocated separately).  Every character that
 * the kernel emits via putchar() is appended to the ring with
 * wrap-around so /etc/dmesg can snoop it via /dev/mem + nlist.
 */
#define MSGBUFS	128
extern char msgbuf[MSGBUFS];
extern char *msgbufp;

void
putchar(char c)
{
	if(c == '\n')
		putchar('\r');
	/* mask off bit 7: historic v7 getty/tty sets parity via partab[],
	 * but PL011 is configured 8N1 (no parity), so high bit corrupts output */
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

/* getchar_ready -- non-blocking probe.  Returns 1 if the receive FIFO
 * has a character pending, 0 otherwise.  Callers that want to yield
 * to other multitasking peers while waiting for input poll this in a
 * loop and call back into the scheduler when it returns 0. */
int
getchar_ready(void)
{
	return (UART0_FR & RXFE) ? 0 : 1;
}
