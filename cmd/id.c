/*
 * id - print the calling user's uid (V7 mission stub).
 */
#include "../lib/u.h"

static char buf[32];

static int
emit_uint(char *out, int n, unsigned int v)
{
	int i, j;

	if(v == 0) {
		out[0] = '0';
		return(1);
	}
	i = 0;
	while(v && i < n) {
		out[i++] = '0' + (v % 10);
		v /= 10;
	}
	for(j = 0; j < i / 2; j++) {
		char t = out[j];
		out[j] = out[i-1-j];
		out[i-1-j] = t;
	}
	return(i);
}

int
main(void)
{
	int uid, n;

	uid = getuid();
	n = 0;
	buf[n++] = 'u';
	buf[n++] = 'i';
	buf[n++] = 'd';
	buf[n++] = '=';
	n += emit_uint(buf + n, sizeof(buf) - n - 2, (unsigned int)uid);
	buf[n++] = '\n';
	(void)write(1, buf, n);
	return(0);
}
