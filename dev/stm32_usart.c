/* STM32MP135 USART4 console driver.
 *
 * The bench's FT2232H captures UART4 at 0x40010000 (the same port
 * ssh.md exercises for the Linux build).  The bootloader has already
 * configured baud + framing by the time `jump` lands, so we only
 * need to spin on TXE/RXNE and shovel bytes through TDR/RDR. */

#define USART4_BASE 0x40010000U
#define USART4_ISR  *((volatile unsigned int *)(USART4_BASE + 0x1cU))
#define USART4_RDR  *((volatile unsigned int *)(USART4_BASE + 0x24U))
#define USART4_TDR  *((volatile unsigned int *)(USART4_BASE + 0x28U))

#define ISR_RXNE    (1U << 5)
#define ISR_TXE     (1U << 7)

void
putchar(char c)
{
	if(c == '\n')
		putchar('\r');
	while((USART4_ISR & ISR_TXE) == 0)
		;
	USART4_TDR = (unsigned char)c;
}

int
getchar(void)
{

	while((USART4_ISR & ISR_RXNE) == 0)
		;
	return((int)(USART4_RDR & 0xffU));
}
