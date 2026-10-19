#include <stdio.h>
#include <math.h>

static void
ck(char *what, int ok)
{
	printf("%s %s\n", ok? "PASS": "FAIL", what);
}

int
main(int argc, char **argv)
{
	char buf[200], b2[200], big[300], path[400];
	char *nenv[3], *av[3];
	int i, n, x, y;
	short h;
	long l;
	float f;
	double d, ip;
	char *p, *q;
	char sw[8];

	if (argc > 1) {
		printf("EXECVP-OK %s\n", argv[1]);
		return 0;
	}
	n = sscanf("\351abc def", "%s %s", buf, b2);
	ck("8bit %s",
	    n == 2 && strcmp(buf, "\351abc") == 0 &&
	    strcmp(b2, "def") == 0);
	n = sscanf("\351\352\351x", "%[\351\352]", buf);
	ck("8bit %[", n == 1 && strcmp(buf, "\351\352\351") == 0);
	n = sscanf("\377 ab", "%s", buf);
	ck("0377 %s", n == 1 && strcmp(buf, "\377") == 0);
	n = sscanf("abcabd", "%[abc", buf);
	ck("unterminated %[", n == 1 && strcmp(buf, "abcab") == 0);
	n = sscanf("xyz", "%[^]", buf);
	printf("info %%[^] n=%d\n", n);
	for (i = 0; i < 150; i++)
		big[i] = '1';
	big[150] = 0;
	x = 7;
	n = sscanf(big, "%d", &x);
	ck("long number", n == 1);
	n = sscanf("-12 34 56789 2.5 3.25 Z hello",
	    "%hd %d %ld %f %lf %c %s",
	    &h, &x, &l, &f, &d, buf, b2);
	ck("types",
	    n == 7 && h == -12 && x == 34 && l == 56789 && f == 2.5 &&
	    d == 3.25 && buf[0] == 'Z' && strcmp(b2, "hello") == 0);
	n = sscanf("1 2", "%*d %d", &x);
	ck("suppress", n == 1 && x == 2);
	n = sscanf("17 ff 1.5E2", "%o %x %F", &x, &y, &d);
	ck("o x F", n == 3 && x == 15 && y == 255 && d == 150.0);

	ck("malloc huge",
	    malloc(0xffffffff) == 0 && malloc(0xfffffffc) == 0 &&
	    malloc(0x80000000) == 0 && malloc(0x7fffff00) == 0);
	p = malloc(100);
	q = malloc(5000);
	ck("malloc small", p != 0 && q != 0 && q != p);
	free(q);
	q = malloc(4000);
	ck("malloc reuse", q != 0);

	ck("atof huge", atof("1e99999999999") > 1e308);
	ck("atof neg huge", atof("1e-99999999999") == 0);
	d = atof("0e500");
	ck("atof 0e500", d == 0);
	ck("atof 0e99999999999", atof("0e99999999999") == 0);
	ck("atof plain",
	    atof("1.5e3") == 1500 && atof("-2.25") == -2.25);

	d = modf(-3.75, &ip);
	ck("modf", d == -0.75 && ip == -3);
	d = modf(0.5, &ip);
	ck("modf small", d == 0.5 && ip == 0);
	d = frexp(0.375, &x);
	ck("frexp", d == 0.75 && x == -1);
	d = frexp(1e-310, &x);
	ck("frexp denormal", x == -1029 && d >= 0.5 && d < 1);

	strcpy(sw, "abcdef");
	swab(sw, sw, 6);
	ck("swab inplace", strcmp(sw, "badcfe") == 0);
	swab("1234", buf, 4);
	buf[4] = 0;
	ck("swab", strcmp(buf, "2143") == 0);

	srand(1);
	x = rand();
	y = rand();
	printf("rand %d %d %d\n", x, y, rand());

	sleep(1);
	ck("sleep", 1);

	strcpy(path, "PATH=");
	for (i = 5; i < 305; i++)
		path[i] = 'a';
	path[i] = 0;
	strcat(path, ":/:/usr/local/test/utils");
	nenv[0] = path;
	nenv[1] = 0;
	environ = nenv;
	av[0] = "tt";
	av[1] = "child";
	av[2] = 0;
	fflush(stdout);
	execvp("tt", av);
	printf("FAIL execvp\n");
	return 0;
}
