#include <stdio.h>

static float deltx;
static float delty;

static float obotx = 0.0f;
static float oboty = 0.0f;
static float botx = 0.0f;
static float boty = 0.0f;
static float scalex = 1.0f;
static float scaley = 1.0f;
static int scaleflag = 0;

static int oloy = -1;
static int ohiy = -1;
static int ohix = -1;
static int oextra = -1;

static int fplt(FILE *fin);
static int getsi(FILE *fin);
static int getstr(char *s, int n, FILE *fin);
static int openpl(void);
static int closepl(void);
static int erase(void);
static int label(char *s);
static int linemod(char *s);
static int line(int x0, int y0, int x1, int y1);
static int move(int xi, int yi);
static int cont(int x, int y);
static int point(int xi, int yi);
static int space(int x0, int y0, int x1, int y1);
static int arc(int x, int y, int x0, int y0, int x1, int y1);
static int circle(int x, int y, int r);
static int dot(int xi, int yi, int dx, int n, int *pat);
static int putch(int c);
static int iabs(int a);
static int quad(int x, int y, int xp, int yp);
static int step(int d);
static double dsqrt(double v);

static int del = 20;

int
main(int argc, char **argv)
{
	int std = 1;
	FILE *fin;

	while (argc-- > 1) {
		if (argv[1][0] == '-') {
			switch (argv[1][1]) {
			case 'l':
				deltx = atoi(&argv[1][2]) - 1;
				break;
			case 'w':
				delty = atoi(&argv[1][2]) - 1;
				break;
			}
		} else {
			std = 0;
			fin = fopen(argv[1], "r");
			if (fin == NULL) {
				fprintf(stderr, "can't open %s\n", argv[1]);
				exit(1);
			}
			fplt(fin);
		}
		argv++;
	}
	if (std)
		fplt(stdin);
	return(0);
}

static int
fplt(FILE *fin)
{
	int c;
	char s[256];
	int xi, yi, x0, y0, x1, y1, r, dx, n, i;
	int pat[256];

	openpl();
	while ((c = getc(fin)) != EOF) {
		switch (c) {
		case 'm':
			xi = getsi(fin);
			yi = getsi(fin);
			move(xi, yi);
			break;
		case 'l':
			x0 = getsi(fin);
			y0 = getsi(fin);
			x1 = getsi(fin);
			y1 = getsi(fin);
			line(x0, y0, x1, y1);
			break;
		case 't':
			getstr(s, sizeof(s), fin);
			label(s);
			break;
		case 'e':
			erase();
			break;
		case 'p':
			xi = getsi(fin);
			yi = getsi(fin);
			point(xi, yi);
			break;
		case 'n':
			xi = getsi(fin);
			yi = getsi(fin);
			cont(xi, yi);
			break;
		case 's':
			x0 = getsi(fin);
			y0 = getsi(fin);
			x1 = getsi(fin);
			y1 = getsi(fin);
			space(x0, y0, x1, y1);
			break;
		case 'a':
			xi = getsi(fin);
			yi = getsi(fin);
			x0 = getsi(fin);
			y0 = getsi(fin);
			x1 = getsi(fin);
			y1 = getsi(fin);
			arc(xi, yi, x0, y0, x1, y1);
			break;
		case 'c':
			xi = getsi(fin);
			yi = getsi(fin);
			r = getsi(fin);
			circle(xi, yi, r);
			break;
		case 'f':
			getstr(s, sizeof(s), fin);
			linemod(s);
			break;
		case 'd':
			xi = getsi(fin);
			yi = getsi(fin);
			dx = getsi(fin);
			n = getsi(fin);
			for (i = 0; i < n; i++) {
				if (i < 256)
					pat[i] = getsi(fin);
				else
					(void)getsi(fin);
			}
			if (n > 256)
				n = 256;
			dot(xi, yi, dx, n, pat);
			break;
		}
	}
	closepl();
	return(0);
}

static int
getsi(FILE *fin)
{
	int a, b;

	b = getc(fin);
	if (b == EOF)
		return(EOF);
	a = getc(fin);
	if (a == EOF)
		return(EOF);
	return(((a & 0377) << 8) | (b & 0377));
}

static int
getstr(char *s, int n, FILE *fin)
{
	int c;

	while (--n > 0) {
		c = getc(fin);
		if (c == EOF || c == '\0')
			break;
		if (c == '\n')
			break;
		*s++ = c;
	}
	*s = '\0';
	return(0);
}

static int
openpl(void)
{
	return(0);
}

static int
closepl(void)
{
	putch(037);
	fflush(stdout);
	return(0);
}

static int
erase(void)
{
	putch(033);
	putch(014);
	ohiy = -1;
	ohix = -1;
	oextra = -1;
	oloy = -1;
	sleep(2);
	return(0);
}

static int
label(char *s)
{
	static char lbl_mv[] = {
		036, 040, 0110, 0110, 0110, 0110, 0110, 0110,
		0112, 0112, 0112, 0112, 0112, 0112, 0112, 0112,
		0112, 0112, 037, 0
	};
	static char lbl_umv[] = {
		036, 040, 0104, 0104, 0104, 0104, 0104, 0104,
		0105, 0105, 0105, 0105, 0105, 0105, 0105, 0105,
		0105, 0105, 037, 0
	};
	int i, c;

	for (i = 0; (c = lbl_mv[i]) != 0; i++)
		putch(c);
	for (i = 0; (c = s[i]) != 0; i++)
		putch(c);
	for (i = 0; (c = lbl_umv[i]) != 0; i++)
		putch(c);
	return(0);
}

static int
linemod(char *s)
{
	char c = 'd';

	putch(033);
	switch (s[0]) {
	case 'l':
		c = 'd';
		break;
	case 'd':
		if (s[3] != 'd')
			c = 'a';
		else
			c = 'b';
		break;
	case 's':
		if (s[5] != '\0')
			c = 'c';
		else
			c = '`';
		break;
	}
	putch(c);
	return(0);
}

static int
line(int x0, int y0, int x1, int y1)
{
	move(x0, y0);
	cont(x1, y1);
	return(0);
}

static int
move(int xi, int yi)
{
	putch(035);
	cont(xi, yi);
	return(0);
}

static int
cont(int x, int y)
{
	int hix, hiy, lox, loy, extra;
	int n;

	x = (int)((x - obotx) * scalex + botx);
	y = (int)((y - oboty) * scaley + boty);
	hix = (x >> 7) & 037;
	hiy = (y >> 7) & 037;
	lox = (x >> 2) & 037;
	loy = (y >> 2) & 037;
	extra = (x & 03) + ((y << 2) & 014);
	n = (iabs(hix - ohix) + iabs(hiy - ohiy) + 6) / 12;
	if (hiy != ohiy) {
		putch(hiy | 040);
		ohiy = hiy;
	}
	if (hix != ohix) {
		if (extra != oextra) {
			putch(extra | 0140);
			oextra = extra;
		}
		putch(loy | 0140);
		putch(hix | 040);
		ohix = hix;
		oloy = loy;
	} else {
		if (extra != oextra) {
			putch(extra | 0140);
			putch(loy | 0140);
			oextra = extra;
			oloy = loy;
		} else if (loy != oloy) {
			putch(loy | 0140);
			oloy = loy;
		}
	}
	putch(lox | 0100);
	while (n-- != 0)
		putch(0);
	return(0);
}

static int
point(int xi, int yi)
{
	move(xi, yi);
	cont(xi, yi);
	return(0);
}

static int
space(int x0, int y0, int x1, int y1)
{
	botx = 0.0f;
	boty = 0.0f;
	obotx = x0;
	oboty = y0;
	if (scaleflag)
		return(0);
	scalex = 3120.0f / (x1 - x0);
	scaley = 3120.0f / (y1 - y0);
	return(0);
}

static int
arc(int x, int y, int x0, int y0, int x1, int y1)
{
	double pc;
	int flg, m, xc, yc, xs, ys, qs, qf;
	float dx, dy, r;
	char use;

	dx = x - x0;
	dy = y - y0;
	r = dx * dx + dy * dy;
	pc = dsqrt((double)r);
	flg = (int)(pc / 4.0);
	if (flg == 0)
		step(1);
	else if (flg < del)
		step(flg);
	xc = xs = x0;
	yc = ys = y0;
	move(xs, ys);
	if (x0 == x1 && y0 == y1)
		flg = 0;
	else
		flg = 1;
	qs = quad(x, y, x0, y0);
	qf = quad(x, y, x1, y1);
	if (iabs(x - x1) < iabs(y - y1)) {
		use = 'x';
		if (qs == 2 || qs == 3)
			m = -1;
		else
			m = 1;
	} else {
		use = 'y';
		if (qs > 2)
			m = -1;
		else
			m = 1;
	}
	for (;;) {
		switch (use) {
		case 'x':
			if (qs == 2 || qs == 3)
				yc -= del;
			else
				yc += del;
			dy = yc - y;
			pc = r - dy * dy;
			xc = (int)(m * dsqrt(pc) + x);
			if ((x < xs && x >= xc) || (x > xs && x <= xc) ||
			    (y < ys && y >= yc) || (y > ys && y <= yc)) {
				if (++qs > 4)
					qs = 1;
				if (qs == 2 || qs == 3)
					m = -1;
				else
					m = 1;
				flg = 1;
			}
			cont(xc, yc);
			xs = xc;
			ys = yc;
			if (qs == qf && flg == 1) {
				switch (qf) {
				case 3:
				case 4:
					if (xs >= x1)
						return(0);
					break;
				case 1:
				case 2:
					if (xs <= x1)
						return(0);
					break;
				}
			}
			break;
		case 'y':
			if (qs > 2)
				xc += del;
			else
				xc -= del;
			dx = xc - x;
			pc = r - dx * dx;
			yc = (int)(m * dsqrt(pc) + y);
			if ((x < xs && x >= xc) || (x > xs && x <= xc) ||
			    (y < ys && y >= yc) || (y > ys && y <= yc)) {
				if (++qs > 4)
					qs = 1;
				if (qs > 2)
					m = -1;
				else
					m = 1;
				flg = 1;
			}
			cont(xc, yc);
			xs = xc;
			ys = yc;
			if (qs == qf && flg == 1) {
				switch (qs) {
				case 1:
				case 4:
					if (ys >= y1)
						return(0);
					break;
				case 2:
				case 3:
					if (ys <= y1)
						return(0);
					break;
				}
			}
			break;
		}
	}
}

static int
circle(int x, int y, int r)
{
	arc(x, y, x + r, y, x + r, y);
	return(0);
}

static int
dot(int xi, int yi, int dx, int n, int *pat)
{
	(void)xi;
	(void)yi;
	(void)dx;
	(void)n;
	(void)pat;
	return(0);
}

static int
putch(int c)
{
	putc(c, stdout);
	return(0);
}

static int
iabs(int a)
{
	if (a < 0)
		return(-a);
	return(a);
}

static int
quad(int x, int y, int xp, int yp)
{
	if (x < xp) {
		if (y <= yp)
			return(1);
		return(4);
	}
	if (x > xp) {
		if (y < yp)
			return(2);
		return(3);
	}
	if (y < yp)
		return(2);
	return(4);
}

static int
step(int d)
{
	del = d;
	return(0);
}

static double
dsqrt(double v)
{
	double x;
	int i;

	if (v <= 0.0)
		return(0.0);
	x = v;
	if (x < 1.0)
		x = 1.0;
	for (i = 0; i < 20; i++)
		x = 0.5 * (x + v / x);
	return(x);
}
