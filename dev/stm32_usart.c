/* STM32MP135 USART4 console driver.
 *
 * The bench's FT2232H captures UART4 at 0x40010000 (the same port
 * ssh.md exercises for the Linux build).  The bootloader has already
 * configured baud + framing by the time `jump` lands, so we only
 * need to spin on TXE/RXNE and shovel bytes through TDR/RDR.
 *
 * Real-hardware caveat: with the USART FIFO disabled, an RDR overrun
 * latches ISR.ORE *and* suppresses further RXNE assertions, so a
 * single missed read wedges getchar() forever.  This bites V7 cooked
 * mode: the shell spends a non-trivial slice of time between each
 * getchar() echoing the previous byte and bouncing through ttyinput,
 * which is plenty of time for the next bench byte (sent at ~80 ms
 * cadence) to overrun.  We mitigate both ways:
 *   (a) enable the 8-byte hardware RX FIFO so the shell has slack;
 *   (b) on every read, if ORE is set, clear it via ICR.ORECF and
 *       drain RDR so RXNE can re-assert on subsequent bytes. */

#define USART4_BASE 0x40010000U
#define USART4_CR1  *((volatile unsigned int *)(USART4_BASE + 0x00U))
#define USART4_ISR  *((volatile unsigned int *)(USART4_BASE + 0x1cU))
#define USART4_ICR  *((volatile unsigned int *)(USART4_BASE + 0x20U))
#define USART4_RDR  *((volatile unsigned int *)(USART4_BASE + 0x24U))
#define USART4_TDR  *((volatile unsigned int *)(USART4_BASE + 0x28U))

#define CR1_UE      (1U << 0)
#define CR1_FIFOEN  (1U << 29)
#define ISR_RXNE    (1U << 5)   /* also RXFNE when FIFO enabled */
#define ISR_TXE     (1U << 7)   /* also TXFNF when FIFO enabled */
#define ISR_ORE     (1U << 3)
#define ICR_ORECF   (1U << 3)

static int usart_fifo_inited = 0;

static void
usart_fifo_init(void)
{
	unsigned int cr1;

	if(usart_fifo_inited)
		return;
	usart_fifo_inited = 1;

	/* Switching FIFOEN requires UE=0 per RM0475.  The bootloader
	 * leaves UE=1, baud and framing set, so we just toggle UE,
	 * flip FIFOEN, and re-enable.  Any pending ORE is cleared on
	 * the way out so the first read does not have to. */
	cr1 = USART4_CR1;
	USART4_CR1 = cr1 & ~CR1_UE;
	USART4_CR1 = (cr1 & ~CR1_UE) | CR1_FIFOEN;
	USART4_ICR = ICR_ORECF;
	USART4_CR1 = (cr1 & ~CR1_UE) | CR1_FIFOEN | CR1_UE;
}

void
putchar(char c)
{
	if(c == '\n')
		putchar('\r');
	usart_fifo_init();
	while((USART4_ISR & ISR_TXE) == 0)
		;
	USART4_TDR = (unsigned char)c;
}

int
getchar(void)
{

	usart_fifo_init();
	for(;;){
		unsigned int isr = USART4_ISR;
		if(isr & ISR_ORE){
			/* An overrun has latched: clear ORECF so RXNE
			 * can fire again, and drain whatever survived
			 * in RDR (one byte's worth on a FIFO-less
			 * USART, up to 8 with FIFO).  The lost bytes
			 * are lost, but the channel stays alive. */
			USART4_ICR = ICR_ORECF;
			(void)USART4_RDR;
			continue;
		}
		if(isr & ISR_RXNE)
			return((int)(USART4_RDR & 0xffU));
	}
}
