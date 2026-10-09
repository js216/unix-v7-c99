typedef int jmp_buf[10];
int	setjmp(jmp_buf env), longjmp(jmp_buf env, int val);
