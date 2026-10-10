#include <stdio.h>

extern int errno;
char s[700][11];
char *v[702];

int
main(void)
{
	int i;

	v[0] = "argt";
	for (i = 0; i < 700; i++) {
		s[i][0] = 'a' + i % 26;
		s[i][1] = '0' + i / 100;
		s[i][2] = '0' + i / 10 % 10;
		s[i][3] = '0' + i % 10;
		s[i][4] = 'y'; s[i][5] = 'y'; s[i][6] = 'y'; s[i][7] = 'y'; s[i][8] = 'y';
		v[i + 1] = s[i];
	}
	v[701] = 0;
	printf("big %d errno %d\n", execv("/usr/local/test/utils/argt", v), errno);
	v[501] = 0;
	execv("/usr/local/test/utils/argt", v);
	printf("exec failed\n");
	return 1;
}
