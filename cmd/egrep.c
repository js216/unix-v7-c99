/*
 * egrep -- print lines containing (or not containing) a regular expression
 *
 *	status returns:
 *		0 - ok, and some matches
 *		1 - ok, but no matches
 *		2 - some error
 *
 * This is a C99 translation of the V7 egrep.y.  The original yacc grammar
 * is represented by the small recursive-descent parser below; the syntax
 * tree, follow-set, DFA construction, and executor are kept close to V7.
 */

#include <stdio.h>

#define MAXLIN 350
#define MAXPOS 4000
#define NCHARS 128
#define NSTATES 128
#define FINAL -1

#define CHAR 128
#define DOT 129
#define CCL 130
#define NCCL 131
#define OR 132
#define CAT 133
#define STAR 134
#define PLUS 135
#define QUEST 136

char gotofn[NSTATES][NCHARS];
int state[NSTATES];
char out[NSTATES];
int line = 1;
int name[MAXLIN];
int left[MAXLIN];
int right[MAXLIN];
int parent[MAXLIN];
int foll[MAXLIN];
int positions[MAXPOS];
char chars[MAXLIN];
int nxtpos;
int nxtchar = 0;
int tmpstat[MAXLIN];
int initstat[MAXLIN];
int xstate;
int count;
int icount;
char *input;

long	lnum;
int	bflag;
int	cflag;
int	fflag;
int	lflag;
int	nflag;
int	hflag	= 1;
int	sflag;
int	vflag;
int	nfile;
long	blkno;
long	tln;
int	nsucc;

int	f;
char	*fname;

int looktok;
int yylval;

void yyerror(char *s);
int yylex(void);
int nextch(void);
void synerror(void);
int enter(int x);
int cclenter(int x);
int node(int x, int l, int r);
int unary(int x, int d);
void overflo(void);
void cfoll(int v);
void cgotofn(void);
int cstate(int v);
int member(int symb, int set, int torf);
int notin(int n);
void add(int *array, int n);
void follow(int v);
int yyparse(void);
void nexttok(void);
int parse_alt(void);
int parse_cat(void);
int parse_post(void);
int parse_atom(void);
int atom_start(int tok);
void execute(char *file);

void
yyerror(char *s)
{
	fprintf(stderr, "egrep: %s\n", s);
	exit(2);
}

int
yylex(void)
{
	int cclcnt, x;
	int c, d;

	switch (c = nextch()) {
	case '$':
	case '^':
		c = '\n';
		goto defchar;
	case '|':
		return (OR);
	case '*':
		return (STAR);
	case '+':
		return (PLUS);
	case '?':
		return (QUEST);
	case '(':
	case ')':
		return (c);
	case '.':
		return (DOT);
	case '\0':
		return (0);
	case '\n':
		return (OR);
	case '[':
		x = CCL;
		cclcnt = 0;
		count = nxtchar++;
		if ((c = nextch()) == '^') {
			x = NCCL;
			c = nextch();
		}
		do {
			if (c == '\0')
				synerror();
			if (c == '-' && cclcnt > 0 && chars[nxtchar-1] != 0) {
				if ((d = nextch()) != 0) {
					c = chars[nxtchar-1];
					while (c < d) {
						if (nxtchar >= MAXLIN)
							overflo();
						chars[nxtchar++] = ++c;
						cclcnt++;
					}
					continue;
				}
			}
			if (nxtchar >= MAXLIN)
				overflo();
			chars[nxtchar++] = c;
			cclcnt++;
		} while ((c = nextch()) != ']');
		chars[count] = cclcnt;
		return (x);
	case '\\':
		if ((c = nextch()) == '\0')
			synerror();
		goto defchar;
	default:
	defchar:
		yylval = c;
		return (CHAR);
	}
}

int
nextch(void)
{
	int c;

	if (fflag) {
		if ((c = getc(stdin)) == EOF)
			return (0);
		return (c);
	}
	return (*input++);
}

void
synerror(void)
{
	fprintf(stderr, "egrep: syntax error\n");
	exit(2);
}

int
enter(int x)
{
	if (line >= MAXLIN)
		overflo();
	name[line] = x;
	left[line] = 0;
	right[line] = 0;
	return (line++);
}

int
cclenter(int x)
{
	int linno;

	linno = enter(x);
	right[linno] = count;
	return (linno);
}

int
node(int x, int l, int r)
{
	if (line >= MAXLIN)
		overflo();
	name[line] = x;
	left[line] = l;
	right[line] = r;
	parent[l] = line;
	parent[r] = line;
	return (line++);
}

int
unary(int x, int d)
{
	if (line >= MAXLIN)
		overflo();
	name[line] = x;
	left[line] = d;
	right[line] = 0;
	parent[d] = line;
	return (line++);
}

void
overflo(void)
{
	fprintf(stderr, "egrep: regular expression too long\n");
	exit(2);
}

void
nexttok(void)
{
	looktok = yylex();
}

int
atom_start(int tok)
{
	return (tok == CHAR || tok == DOT || tok == CCL || tok == NCCL ||
	    tok == '(');
}

int
yyparse(void)
{
	int b, r;

	nexttok();
	if (looktok == OR)
		nexttok();
	b = enter(DOT);
	b = unary(STAR, b);
	r = parse_alt();
	if (looktok == OR)
		nexttok();
	if (looktok != 0)
		synerror();
	unary(FINAL, node(CAT, b, r));
	line--;
	return (0);
}

int
parse_alt(void)
{
	int l, r;

	l = parse_cat();
	while (looktok == OR) {
		nexttok();
		if (looktok == 0 || looktok == ')')
			break;
		r = parse_cat();
		l = node(OR, l, r);
	}
	return (l);
}

int
parse_cat(void)
{
	int l, r;

	if (!atom_start(looktok))
		synerror();
	l = parse_post();
	while (atom_start(looktok)) {
		r = parse_post();
		l = node(CAT, l, r);
	}
	return (l);
}

int
parse_post(void)
{
	int a;

	a = parse_atom();
	for (;;) {
		if (looktok == STAR) {
			nexttok();
			a = unary(STAR, a);
		} else if (looktok == PLUS) {
			nexttok();
			a = unary(PLUS, a);
		} else if (looktok == QUEST) {
			nexttok();
			a = unary(QUEST, a);
		} else
			return (a);
	}
}

int
parse_atom(void)
{
	int a;

	switch (looktok) {
	case CHAR:
		a = enter(yylval);
		nexttok();
		return (a);
	case DOT:
		a = enter(DOT);
		nexttok();
		return (a);
	case CCL:
		a = cclenter(CCL);
		nexttok();
		return (a);
	case NCCL:
		a = cclenter(NCCL);
		nexttok();
		return (a);
	case '(':
		nexttok();
		a = parse_alt();
		if (looktok != ')')
			synerror();
		nexttok();
		return (a);
	default:
		synerror();
		return (0);
	}
}

void
cfoll(int v)
{
	int i;

	if (left[v] == 0) {
		count = 0;
		for (i = 1; i <= line; i++)
			tmpstat[i] = 0;
		follow(v);
		add(foll, v);
	} else if (right[v] == 0)
		cfoll(left[v]);
	else {
		cfoll(left[v]);
		cfoll(right[v]);
	}
}

void
cgotofn(void)
{
	int c, i, k;
	int n, s;
	char symbol[NCHARS];
	int j, nc, pc, pos;
	int curpos, num;
	int number, newpos;

	count = 0;
	for (n = 3; n <= line; n++)
		tmpstat[n] = 0;
	if (cstate(line-1) == 0) {
		tmpstat[line] = 1;
		count++;
		out[0] = 1;
	}
	for (n = 3; n <= line; n++)
		initstat[n] = tmpstat[n];
	count--;
	icount = count;
	tmpstat[1] = 0;
	add(state, 0);
	n = 0;
	for (s = 0; s <= n; s++)  {
		if (out[s] == 1)
			continue;
		for (i = 0; i < NCHARS; i++)
			symbol[i] = 0;
		num = positions[state[s]];
		count = icount;
		for (i = 3; i <= line; i++)
			tmpstat[i] = initstat[i];
		pos = state[s] + 1;
		for (i = 0; i < num; i++) {
			curpos = positions[pos];
			if ((c = name[curpos]) >= 0) {
				if (c < NCHARS)
					symbol[c] = 1;
				else if (c == DOT) {
					for (k = 0; k < NCHARS; k++)
						if (k != '\n')
							symbol[k] = 1;
				} else if (c == CCL) {
					nc = chars[right[curpos]];
					pc = right[curpos] + 1;
					for (k = 0; k < nc; k++)
						symbol[(int)chars[pc++]] = 1;
				} else if (c == NCCL) {
					nc = chars[right[curpos]];
					for (j = 0; j < NCHARS; j++) {
						pc = right[curpos] + 1;
						for (k = 0; k < nc; k++)
							if (j == chars[pc++])
								goto cont;
						if (j != '\n')
							symbol[j] = 1;
cont:
						;
					}
				} else
					printf("something's funny\n");
			}
			pos++;
		}
		for (c = 0; c < NCHARS; c++) {
			if (symbol[c] == 1) {
				count = icount;
				for (i = 3; i <= line; i++)
					tmpstat[i] = initstat[i];
				pos = state[s] + 1;
				for (i = 0; i < num; i++) {
					curpos = positions[pos];
					if ((k = name[curpos]) >= 0)
						if (
						    (k == c)
						    | (k == DOT)
						    | (k == CCL && member(c, right[curpos], 1))
						    | (k == NCCL && member(c, right[curpos], 0))
						) {
							number = positions[foll[curpos]];
							newpos = foll[curpos] + 1;
							for (k = 0; k < number; k++) {
								if (tmpstat[positions[newpos]] != 1) {
									tmpstat[positions[newpos]] = 1;
									count++;
								}
								newpos++;
							}
						}
					pos++;
				}
				if (notin(n)) {
					if (n >= NSTATES)
						overflo();
					add(state, ++n);
					if (tmpstat[line] == 1)
						out[n] = 1;
					gotofn[s][c] = n;
				} else
					gotofn[s][c] = xstate;
			}
		}
	}
}

int
cstate(int v)
{
	int b;

	if (left[v] == 0) {
		if (tmpstat[v] != 1) {
			tmpstat[v] = 1;
			count++;
		}
		return (1);
	} else if (right[v] == 0) {
		if (cstate(left[v]) == 0)
			return (0);
		else if (name[v] == PLUS)
			return (1);
		else
			return (0);
	} else if (name[v] == CAT) {
		if (cstate(left[v]) == 0 && cstate(right[v]) == 0)
			return (0);
		else
			return (1);
	} else {
		b = cstate(right[v]);
		if (cstate(left[v]) == 0 || b == 0)
			return (0);
		else
			return (1);
	}
}

int
member(int symb, int set, int torf)
{
	int i, num, pos;

	num = chars[set];
	pos = set + 1;
	for (i = 0; i < num; i++)
		if (symb == chars[pos++])
			return (torf);
	return (!torf);
}

int
notin(int n)
{
	int i, j, pos;

	for (i = 0; i <= n; i++) {
		if (positions[state[i]] == count) {
			pos = state[i] + 1;
			for (j = 0; j < count; j++)
				if (tmpstat[positions[pos++]] != 1)
					goto nxt;
			xstate = i;
			return (0);
		}
nxt:
		;
	}
	return (1);
}

void
add(int *array, int n)
{
	int i;

	if (nxtpos + count > MAXPOS)
		overflo();
	array[n] = nxtpos;
	positions[nxtpos++] = count;
	for (i = 3; i <= line; i++) {
		if (tmpstat[i] == 1) {
			positions[nxtpos++] = i;
		}
	}
}

void
follow(int v)
{
	int p;

	if (v == line)
		return;
	p = parent[v];
	switch (name[p]) {
	case STAR:
	case PLUS:
		cstate(v);
		follow(p);
		return;
	case OR:
	case QUEST:
		follow(p);
		return;
	case CAT:
		if (v == left[p]) {
			if (cstate(right[p]) == 0) {
				follow(p);
				return;
			}
		} else
			follow(p);
		return;
	case FINAL:
		if (tmpstat[line] != 1) {
			tmpstat[line] = 1;
			count++;
		}
		return;
	}
}

int
main(int argc, char **argv)
{
	while (--argc > 0 && (++argv)[0][0] == '-')
		switch (argv[0][1]) {
		case 's':
			sflag++;
			continue;
		case 'h':
			hflag = 0;
			continue;
		case 'b':
			bflag++;
			continue;
		case 'c':
			cflag++;
			continue;
		case 'e':
			argc--;
			argv++;
			goto out;
		case 'f':
			fflag++;
			continue;
		case 'l':
			lflag++;
			continue;
		case 'n':
			nflag++;
			continue;
		case 'v':
			vflag++;
			continue;
		default:
			fprintf(stderr, "egrep: unknown flag\n");
			continue;
		}
out:
	if (argc <= 0)
		exit(2);
	if (fflag) {
		fname = *argv;
		if (freopen(fname, "r", stdin) == NULL) {
			fprintf(stderr, "egrep: can't open %s\n", fname);
			exit(2);
		}
	} else
		input = *argv;
	argc--;
	argv++;

	yyparse();

	cfoll(line-1);
	cgotofn();
	nfile = argc;
	if (argc <= 0) {
		if (lflag)
			exit(1);
		execute(0);
	} else
		while (--argc >= 0) {
			execute(*argv);
			argv++;
		}
	exit(nsucc == 0);
}

void
execute(char *file)
{
	char *p;
	int cstat;
	int ccount;
	char buf[1024];
	char *nlp;
	int istat;

	if (file) {
		if ((f = open(file, 0)) < 0) {
			fprintf(stderr, "egrep: can't open %s\n", file);
			exit(2);
		}
	} else
		f = 0;
	ccount = 0;
	lnum = 1;
	tln = 0;
	p = buf;
	nlp = p;
	if ((ccount = read(f, p, 512)) <= 0)
		goto done;
	blkno = ccount;
	istat = cstat = gotofn[0]['\n'];
	if (out[cstat])
		goto found;
	for (;;) {
		cstat = gotofn[cstat][*p & 0177];
		if (out[cstat]) {
found:
			for (;;) {
				if (*p++ == '\n') {
					if (vflag == 0) {
succeed:
						nsucc = 1;
						if (cflag)
							tln++;
						else if (sflag)
							;
						else if (lflag) {
							printf("%s\n", file);
							close(f);
							return;
						} else {
							if (nfile > 1 && hflag)
								printf("%s:", file);
							if (bflag)
								printf("%ld:", (blkno-ccount-1)/512);
							if (nflag)
								printf("%ld:", lnum);
							if (p <= nlp) {
								while (nlp < &buf[1024])
									putchar(*nlp++);
								nlp = buf;
							}
							while (nlp < p)
								putchar(*nlp++);
						}
					}
					lnum++;
					nlp = p;
					if ((out[(cstat = istat)]) == 0)
						goto brk2;
				}
cfound:
				if (--ccount <= 0) {
					if (p <= &buf[512]) {
						if ((ccount = read(f, p, 512)) <= 0)
							goto done;
					} else if (p == &buf[1024]) {
						p = buf;
						if ((ccount = read(f, p, 512)) <= 0)
							goto done;
					} else {
						if ((ccount = read(f, p, &buf[1024]-p)) <= 0)
							goto done;
					}
					if (nlp > p && nlp <= p+ccount)
						nlp = p+ccount;
					blkno += ccount;
				}
			}
		}
		if (*p++ == '\n') {
			if (vflag)
				goto succeed;
			else {
				lnum++;
				nlp = p;
				if (out[(cstat = istat)])
					goto cfound;
			}
		}
brk2:
		if (--ccount <= 0) {
			if (p <= &buf[512]) {
				if ((ccount = read(f, p, 512)) <= 0)
					break;
			} else if (p == &buf[1024]) {
				p = buf;
				if ((ccount = read(f, p, 512)) <= 0)
					break;
			} else {
				if ((ccount = read(f, p, &buf[1024] - p)) <= 0)
					break;
			}
			if (nlp > p && nlp <= p+ccount)
				nlp = p+ccount;
			blkno += ccount;
		}
	}
done:
	close(f);
	if (cflag) {
		if (nfile > 1)
			printf("%s:", file);
		printf("%ld\n", tln);
	}
}
