#include <stdio.h>

#define ESIZE	512
#define NBRA	9

enum {
	TOK_END = 0,
	TOK_STRING = 256,
	TOK_OR,
	TOK_AND,
	TOK_ADD,
	TOK_SUB,
	TOK_MUL,
	TOK_DIV,
	TOK_REM,
	TOK_COLON,
	TOK_EQ,
	TOK_GT,
	TOK_GEQ,
	TOK_LT,
	TOK_LEQ,
	TOK_NEQ,
	TOK_MATCH,
	TOK_SUBSTR,
	TOK_LENGTH,
	TOK_INDEX
};

struct token {
	int type;
	char *text;
};

static int ac;
static char **av;
static int pos;
static struct token tok;
static char match_string[128];
static int nbra;

static char *parse_or(void);
static char *parse_and(void);
static char *parse_rel(void);
static char *parse_add(void);
static char *parse_mul(void);
static char *parse_colon(void);
static char *parse_unary(void);
static void next(void);
static void syntax(void);
static char *conj(int op, char *r1, char *r2);
static char *relop(int op, char *r1, char *r2);
static char *arith(int op, char *r1, char *r2);
static char *match_op(char *s, char *p);
static char *substr_op(char *v, char *s, char *w);
static char *length_op(char *s);
static char *index_op(char *s, char *t);
static int isnum(char *s, int sign);
static char *numstr(long n);
static char *xalloc(unsigned n);
static int ematch(char *s, char *p);
static void re_error(int c);

int
main(int argc, char *argv[])
{
	char *r;

	ac = argc;
	av = argv;
	pos = 1;
	next();
	if (tok.type == TOK_END)
		syntax();
	r = parse_or();
	if (tok.type != TOK_END)
		syntax();
	printf("%s\n", r);
	exit((strcmp(r, "0") == 0 || strcmp(r, "") == 0) ? 1 : 0);
	return(0);
}

static void
next(void)
{
	char *p;

	if (pos >= ac) {
		tok.type = TOK_END;
		tok.text = "";
		return;
	}
	p = av[pos++];
	tok.text = p;
	if (strcmp(p, "(") == 0 || strcmp(p, ")") == 0) {
		tok.type = *p;
		return;
	}
	if (strcmp(p, "|") == 0) tok.type = TOK_OR;
	else if (strcmp(p, "&") == 0) tok.type = TOK_AND;
	else if (strcmp(p, "+") == 0) tok.type = TOK_ADD;
	else if (strcmp(p, "-") == 0) tok.type = TOK_SUB;
	else if (strcmp(p, "*") == 0) tok.type = TOK_MUL;
	else if (strcmp(p, "/") == 0) tok.type = TOK_DIV;
	else if (strcmp(p, "%") == 0) tok.type = TOK_REM;
	else if (strcmp(p, ":") == 0) tok.type = TOK_COLON;
	else if (strcmp(p, "=") == 0 || strcmp(p, "==") == 0) tok.type = TOK_EQ;
	else if (strcmp(p, ">") == 0) tok.type = TOK_GT;
	else if (strcmp(p, ">=") == 0) tok.type = TOK_GEQ;
	else if (strcmp(p, "<") == 0) tok.type = TOK_LT;
	else if (strcmp(p, "<=") == 0) tok.type = TOK_LEQ;
	else if (strcmp(p, "!=") == 0) tok.type = TOK_NEQ;
	else if (strcmp(p, "match") == 0) tok.type = TOK_MATCH;
	else if (strcmp(p, "substr") == 0) tok.type = TOK_SUBSTR;
	else if (strcmp(p, "length") == 0) tok.type = TOK_LENGTH;
	else if (strcmp(p, "index") == 0) tok.type = TOK_INDEX;
	else tok.type = TOK_STRING;
}

static void
syntax(void)
{
	fprintf(stderr, "syntax error\n");
	exit(2);
}

static char *
parse_or(void)
{
	char *r;

	r = parse_and();
	while (tok.type == TOK_OR) {
		next();
		r = conj(TOK_OR, r, parse_and());
	}
	return(r);
}

static char *
parse_and(void)
{
	char *r;

	r = parse_rel();
	while (tok.type == TOK_AND) {
		next();
		r = conj(TOK_AND, r, parse_rel());
	}
	return(r);
}

static char *
parse_rel(void)
{
	char *r;
	int op;

	r = parse_add();
	while (tok.type == TOK_EQ || tok.type == TOK_GT || tok.type == TOK_GEQ ||
	    tok.type == TOK_LT || tok.type == TOK_LEQ || tok.type == TOK_NEQ) {
		op = tok.type;
		next();
		r = relop(op, r, parse_add());
	}
	return(r);
}

static char *
parse_add(void)
{
	char *r;
	int op;

	r = parse_mul();
	while (tok.type == TOK_ADD || tok.type == TOK_SUB) {
		op = tok.type;
		next();
		r = arith(op, r, parse_mul());
	}
	return(r);
}

static char *
parse_mul(void)
{
	char *r;
	int op;

	r = parse_colon();
	while (tok.type == TOK_MUL || tok.type == TOK_DIV || tok.type == TOK_REM) {
		op = tok.type;
		next();
		r = arith(op, r, parse_colon());
	}
	return(r);
}

static char *
parse_colon(void)
{
	char *r;

	r = parse_unary();
	while (tok.type == TOK_COLON) {
		next();
		r = match_op(r, parse_unary());
	}
	return(r);
}

static char *
parse_unary(void)
{
	char *r, *s, *w;

	if (tok.type == '(') {
		next();
		r = parse_or();
		if (tok.type != ')')
			syntax();
		next();
		return(r);
	}
	if (tok.type == TOK_MATCH) {
		next();
		r = parse_unary();
		return(match_op(r, parse_unary()));
	}
	if (tok.type == TOK_SUBSTR) {
		next();
		r = parse_unary();
		s = parse_unary();
		w = parse_unary();
		return(substr_op(r, s, w));
	}
	if (tok.type == TOK_LENGTH) {
		next();
		return(length_op(parse_unary()));
	}
	if (tok.type == TOK_INDEX) {
		next();
		r = parse_unary();
		return(index_op(r, parse_unary()));
	}
	if (tok.type != TOK_STRING)
		syntax();
	r = tok.text;
	next();
	return(r);
}

static int
false_value(char *s)
{
	return(strcmp(s, "0") == 0 || strcmp(s, "") == 0);
}

static char *
conj(int op, char *r1, char *r2)
{
	if (op == TOK_OR) {
		if (false_value(r1))
			return(false_value(r2) ? "0" : r2);
		return(r1);
	}
	if (false_value(r1) || false_value(r2))
		return("0");
	return(r1);
}

static char *
relop(int op, char *r1, char *r2)
{
	long d;
	int i;

	if (isnum(r1, 1) && isnum(r2, 0))
		d = atol(r1) - atol(r2);
	else
		d = strcmp(r1, r2);
	switch (op) {
	case TOK_EQ: i = d == 0; break;
	case TOK_GT: i = d > 0; break;
	case TOK_GEQ: i = d >= 0; break;
	case TOK_LT: i = d < 0; break;
	case TOK_LEQ: i = d <= 0; break;
	default: i = d != 0; break;
	}
	return(i ? "1" : "0");
}

static char *
arith(int op, char *r1, char *r2)
{
	long i1, i2;

	if (!isnum(r1, 0) || !isnum(r2, 0)) {
		fprintf(stderr, "non-numeric argument\n");
		exit(2);
	}
	i1 = atol(r1);
	i2 = atol(r2);
	if ((op == TOK_DIV || op == TOK_REM) && i2 == 0) {
		fprintf(stderr, "division by zero\n");
		exit(2);
	}
	switch (op) {
	case TOK_ADD: i1 += i2; break;
	case TOK_SUB: i1 -= i2; break;
	case TOK_MUL: i1 *= i2; break;
	case TOK_DIV: i1 /= i2; break;
	default: i1 %= i2; break;
	}
	return(numstr(i1));
}

static char *
substr_op(char *v, char *s, char *w)
{
	int si, wi, len, i;
	char *r;

	si = atoi(s);
	wi = atoi(w);
	len = strlen(v);
	if (si < 1)
		si = 1;
	if (wi < 0)
		wi = 0;
	if (si > len + 1)
		si = len + 1;
	if (wi > len - si + 1)
		wi = len - si + 1;
	r = xalloc((unsigned)wi + 1);
	for (i = 0; i < wi; i++)
		r[i] = v[si - 1 + i];
	r[wi] = '\0';
	return(r);
}

static char *
length_op(char *s)
{
	return(numstr(strlen(s)));
}

static char *
index_op(char *s, char *t)
{
	int i, j;

	for (i = 0; s[i] != '\0'; i++)
		for (j = 0; t[j] != '\0'; j++)
			if (s[i] == t[j])
				return(numstr((long)i + 1));
	return("0");
}

static char *
match_op(char *s, char *p)
{
	char *r;
	int n;

	n = ematch(s, p);
	if (nbra == 1) {
		r = xalloc((unsigned)strlen(match_string) + 1);
		strcpy(r, match_string);
		return(r);
	}
	return(numstr(n));
}

static int
isnum(char *s, int sign)
{
	if (sign)
		while (*s == '-')
			s++;
	while (*s >= '0' && *s <= '9')
		s++;
	return(*s == '\0');
}

static char *
numstr(long n)
{
	char buf[32];
	char *r;

	sprintf(buf, "%ld", n);
	r = xalloc((unsigned)strlen(buf) + 1);
	strcpy(r, buf);
	return(r);
}

static char *
xalloc(unsigned n)
{
	char *p;

	p = malloc(n);
	if (p == 0) {
		fprintf(stderr, "out of memory\n");
		exit(2);
	}
	return(p);
}

#define	CBRA	2
#define	CCHR	4
#define	CDOT	8
#define	CCL	12
#define	CDOL	20
#define	CEOF	22
#define	CKET	24
#define	CBACK	36
#define	STAR	01
#define	RNGE	03

static char *braslist[NBRA];
static char *braelist[NBRA];
static char *loc2;
static char *locs;
static int circf;
static int low;
static int size;
static char bittab[] = { 1, 2, 4, 8, 16, 32, 64, 128 };

#define PLACE(c)	ep[((c) & 0177) >> 3] |= bittab[(c) & 07]
#define ISTHERE(c)	(ep[((c) & 0177) >> 3] & bittab[(c) & 07])

static char *compile_re(char *instring, char *ep, char *endbuf);
static int advance_re(char *lp, char *ep);
static void getrnge(char *str);
static int ecmp(char *a, char *b, int count);

static int
ematch(char *s, char *p)
{
	static char expbuf[ESIZE];
	int num;

	compile_re(p, expbuf, &expbuf[ESIZE]);
	if (nbra > 1) {
		fprintf(stderr, "Too many '\\('s\n");
		exit(2);
	}
	locs = 0;
	if (advance_re(s, expbuf)) {
		if (nbra == 1) {
			p = braslist[0];
			num = braelist[0] - p;
			if (num >= (int)sizeof(match_string))
				num = (int)sizeof(match_string) - 1;
			strncpy(match_string, p, num);
			match_string[num] = '\0';
		}
		return(loc2 - s);
	}
	return(0);
}

static char *
compile_re(char *instring, char *ep, char *endbuf)
{
	char *sp;
	int c, eof, cclcnt, closed, lc, i, cflg;
	char *lastep;
	char bracket[NBRA], *bracketp;
	int neg;

	sp = instring;
	eof = '\0';
	lastep = 0;
	c = *sp++;
	if (c == eof) {
		if (*ep == 0)
			re_error(41);
		return(ep);
	}
	bracketp = bracket;
	circf = closed = nbra = 0;
	if (c == '^')
		circf++;
	else
		sp--;
	for (;;) {
		if (ep >= endbuf)
			re_error(50);
		c = *sp++;
		if (c != '*' && (c != '\\' || *sp != '{'))
			lastep = ep;
		if (c == eof) {
			*ep++ = CEOF;
			return(ep);
		}
		switch (c) {
		case '.':
			*ep++ = CDOT;
			continue;
		case '\n':
			re_error(36);
			/* fallthrough */
		case '*':
			if (lastep == 0 || *lastep == CBRA || *lastep == CKET)
				goto defchar;
			*lastep |= STAR;
			continue;
		case '$':
			if (*sp != eof)
				goto defchar;
			*ep++ = CDOL;
			continue;
		case '[':
			if (&ep[17] >= endbuf)
				re_error(50);
			*ep++ = CCL;
			lc = 0;
			for (i = 0; i < 16; i++)
				ep[i] = 0;
			neg = 0;
			c = *sp++;
			if (c == '^') {
				neg = 1;
				c = *sp++;
			}
			do {
				if (c == '\0' || c == '\n')
					re_error(49);
				if (c == '-' && lc != 0) {
					c = *sp++;
					if (c == ']') {
						PLACE('-');
						break;
					}
					while (lc < c) {
						PLACE(lc);
						lc++;
					}
				}
				lc = c;
				PLACE(c);
				c = *sp++;
			} while (c != ']');
			if (neg) {
				for (cclcnt = 0; cclcnt < 16; cclcnt++)
					ep[cclcnt] ^= -1;
				ep[0] &= 0376;
			}
			ep += 16;
			continue;
		case '\\':
			c = *sp++;
			switch (c) {
			case '(':
				if (nbra >= NBRA)
					re_error(43);
				*bracketp++ = (char)nbra;
				*ep++ = CBRA;
				*ep++ = nbra++;
				continue;
			case ')':
				if (bracketp <= bracket)
					re_error(42);
				*ep++ = CKET;
				*ep++ = *--bracketp;
				closed++;
				continue;
			case '{':
				if (lastep == 0)
					goto defchar;
				*lastep |= RNGE;
				cflg = 0;
			nlim:
				c = *sp++;
				i = 0;
				do {
					if ('0' <= c && c <= '9')
						i = 10 * i + c - '0';
					else
						re_error(16);
					c = *sp++;
				} while (c != '\\' && c != ',');
				if (i > 255)
					re_error(11);
				*ep++ = i;
				if (c == ',') {
					if (cflg++)
						re_error(44);
					c = *sp++;
					if (c == '\\')
						*ep++ = 255;
					else {
						sp--;
						goto nlim;
					}
				}
				if (*sp++ != '}')
					re_error(45);
				if (!cflg)
					*ep++ = i;
				else if ((ep[-1] & 0377) < (ep[-2] & 0377))
					re_error(46);
				continue;
			case '\n':
				re_error(36);
				/* fallthrough */
			default:
				if (c >= '1' && c <= '9') {
					c -= '1';
					if (c >= closed)
						re_error(25);
					*ep++ = CBACK;
					*ep++ = c;
					continue;
				}
			} /* fallthrough */
		defchar:
		default:
			lastep = ep;
			*ep++ = CCHR;
			*ep++ = c;
		}
	}
}

static int
advance_re(char *lp, char *ep)
{
	char *curlp, c, *bbeg;
	int ct;

	for (;;) switch (*ep++) {
	case CCHR:
		if (*ep++ == *lp++)
			continue;
		return(0);
	case CDOT:
		if (*lp++)
			continue;
		return(0);
	case CDOL:
		if (*lp == 0)
			continue;
		return(0);
	case CEOF:
		loc2 = lp;
		return(1);
	case CCL:
		c = *lp++ & 0177;
		if (ISTHERE(c)) {
			ep += 16;
			continue;
		}
		return(0);
	case CBRA:
		braslist[(int)*ep++] = lp;
		continue;
	case CKET:
		braelist[(int)*ep++] = lp;
		continue;
	case CCHR|RNGE:
		c = *ep++;
		getrnge(ep);
		while (low--)
			if (*lp++ != c)
				return(0);
		curlp = lp;
		while (size--)
			if (*lp++ != c)
				break;
		if (size < 0)
			lp++;
		ep += 2;
		goto star;
	case CDOT|RNGE:
		getrnge(ep);
		while (low--)
			if (*lp++ == '\0')
				return(0);
		curlp = lp;
		while (size--)
			if (*lp++ == '\0')
				break;
		if (size < 0)
			lp++;
		ep += 2;
		goto star;
	case CCL|RNGE:
		getrnge(ep + 16);
		while (low--) {
			c = *lp++ & 0177;
			if (!ISTHERE(c))
				return(0);
		}
		curlp = lp;
		while (size--) {
			c = *lp++ & 0177;
			if (!ISTHERE(c))
				break;
		}
		if (size < 0)
			lp++;
		ep += 18;
		goto star;
	case CBACK:
		bbeg = braslist[(int)*ep];
		ct = braelist[(int)*ep++] - bbeg;
		if (ecmp(bbeg, lp, ct)) {
			lp += ct;
			continue;
		}
		return(0);
	case CBACK|STAR:
		bbeg = braslist[(int)*ep];
		ct = braelist[(int)*ep++] - bbeg;
		curlp = lp;
		while (ecmp(bbeg, lp, ct))
			lp += ct;
		while (lp >= curlp) {
			if (advance_re(lp, ep))
				return(1);
			lp -= ct;
		}
		return(0);
	case CDOT|STAR:
		curlp = lp;
		while (*lp++)
			;
		goto star;
	case CCHR|STAR:
		curlp = lp;
		while (*lp++ == *ep)
			;
		ep++;
		goto star;
	case CCL|STAR:
		curlp = lp;
		do {
			c = *lp++ & 0177;
		} while (ISTHERE(c));
		ep += 16;
		goto star;
	star:
		do {
			if (--lp == locs)
				break;
			if (advance_re(lp, ep))
				return(1);
		} while (lp > curlp);
		return(0);
	default:
		re_error(0);
	}
}

static void
getrnge(char *str)
{
	low = *str++ & 0377;
	size = *str == 255 ? 20000 : (*str & 0377) - low;
}

static int
ecmp(char *a, char *b, int count)
{
	if (a == b)
		re_error(51);
	while (count--)
		if (*a++ != *b++)
			return(0);
	return(1);
}

static void
re_error(int c)
{
	(void)c;
	fprintf(stderr, "RE error\n");
	exit(2);
}
