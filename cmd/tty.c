/*
 * Type tty name
 */

char	*ttyname();
int strcmp(char *a, char *b);
int printf(char *fmt, ...);
void exit(int n);

int
main(int argc, char *argv[])
{
	register char *p;

	p = ttyname(0);
	if(argc==2 && !strcmp(argv[1], "-s"))
		;
	else
		printf("%s\n", (p? p: "not a tty"));
	exit(p? 0: 1);
}
