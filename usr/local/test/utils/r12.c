#include <stdio.h>
#include <signal.h>

int gotsig;
void skip(int sig);
__asm__(
"	.text\n"
"	.globl skip\n"
"skip:\n"
"	ldr r1, [sp, #60]\n"
"	add r1, r1, #4\n"
"	str r1, [sp, #60]\n"
"	ldr r2, =gotsig\n"
"	str r0, [r2]\n"
"	bx lr\n"
"	.ltorg\n");

int
main(void)
{
	int out;

	signal(SIGILL, skip);
	__asm__ volatile("mov r12, %1\n\t.word 0xe7f000f0\n\tmov %0, r12"
	    : "=r"(out) : "r"(0x5a5a1234) : "r12");
	printf("undef: sig=%d r12=%x\n", gotsig, out);
	gotsig = 0;
	signal(SIGSEGV, skip);
	__asm__ volatile("mov r12, %1\n\tmov r0, #0x30000000\n\tldr r0, [r0]\n\tmov %0, r12"
	    : "=r"(out) : "r"(0x1234a5a5) : "r0", "r12");
	printf("dabort: sig=%d r12=%x\n", gotsig, out);
	return 0;
}
