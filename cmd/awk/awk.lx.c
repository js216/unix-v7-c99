#include "awk.h"
#include "awk.def"
#include "ctype.h"
#include "stdio.h"

extern int mustfld;
extern FILE *yyin;
extern YYSTYPE yylval;

FILE *yyin = NULL;
int lineno = 1;

#ifdef DEBUG
#define RETURN(x) { if (dbg) ptoken(x); return(x); }
#else
#define RETURN(x) return(x)
#endif

#define CBUFLEN 150

static char cbuf[CBUFLEN];
static int pushed = -1;
static int state = 0;

#define A 0
#define REG 1
#define SC 2

static int
isword1(c)
int c;
{
	return(isalpha(c));
}

static int
isword(c)
int c;
{
	return(isalnum(c));
}

static int
inputc()
{
	int c;
	extern char *lexprog;

	if (pushed >= 0) {
		c = pushed;
		pushed = -1;
		return(c);
	}
	if (yyin == NULL)
		c = *lexprog ? *lexprog++ : EOF;
	else
		c = getc(yyin);
	return(c);
}

static int
unputc(c)
int c;
{
	pushed = c;
	return(0);
}

static int
word(char *s, char *t)
{
	while (*s == *t) {
		if (*s == 0)
			return(1);
		s++;
		t++;
	}
	return(0);
}

static int
readstr()
{
	int c, n;

	n = 0;
	for (;;) {
		c = inputc();
		if (c == EOF || c == 0) {
			yyerror("newline in string");
			break;
		}
		if (c == '\n') {
			lineno++;
			yyerror("newline in string");
			break;
		}
		if (c == '"')
			break;
		if (c == '\\') {
			c = inputc();
			if (c == 'n')
				c = '\n';
			else if (c == 't')
				c = '\t';
			else if (c == EOF || c == 0)
				break;
		}
		if (n >= CBUFLEN-1) {
			yyerror("string too long");
			break;
		}
		cbuf[n++] = c;
	}
	cbuf[n] = 0;
	yylval = (int)setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab);
	RETURN(STRING);
}

static int
readclass(neg)
int neg;
{
	int c, n;

	n = 0;
	for (;;) {
		c = inputc();
		if (c == EOF || c == 0 || c == '\n') {
			if (c == '\n')
				lineno++;
			yyerror("newline in character class");
			state = A;
			RETURN(NL);
		}
		if (c == ']')
			break;
		if (c == '\\') {
			c = inputc();
			if (c == 'n')
				c = '\n';
			else if (c == 't')
				c = '\t';
			else if (c == EOF || c == 0)
				break;
		}
		if (n >= CBUFLEN-1) {
			yyerror("string too long");
			break;
		}
		cbuf[n++] = c;
	}
	cbuf[n] = 0;
	yylval = (int)tostring(cbuf);
	if (neg)
		RETURN(NCCL);
	RETURN(CCL);
}

int
yylex()
{
	int c, d, n;
	char buf[CBUFLEN];

again:
	if (state == SC) {
		state = A;
		RETURN('}');
	}
	c = inputc();
	if (c == EOF || c == 0)
		return(0);

	if (state == REG) {
		switch (c) {
		case '[':
			c = inputc();
			if (c == '^')
				return(readclass(1));
			unputc(c);
			return(readclass(0));
		case '?': RETURN(QUEST);
		case '+': RETURN(PLUS);
		case '*': RETURN(STAR);
		case '|': RETURN(OR);
		case '.': RETURN(DOT);
		case '(':
		case ')':
		case '^':
		case '$':
			RETURN(c);
		case '\\':
			c = inputc();
			if (c == 'n')
				yylval = '\n';
			else if (c == 't')
				yylval = '\t';
			else
				yylval = c;
			RETURN(CHAR);
		case '/':
			state = A;
			unputc('/');
			goto again;
		case '\n':
			lineno++;
			yyerror("newline in regular expression");
			state = A;
			RETURN(NL);
		default:
			yylval = c;
			RETURN(CHAR);
		}
	}

	if (c == ' ' || c == '\t')
		goto again;
	if (c == '#') {
		while ((c = inputc()) != EOF && c != 0 && c != '\n')
			;
		if (c == '\n')
			lineno++;
		RETURN(NL);
	}
	if (c == '\\') {
		d = inputc();
		if (d == '\n') {
			lineno++;
			goto again;
		}
		unputc(d);
	}
	if (c == '\n') {
		lineno++;
		RETURN(NL);
	}
	if (c == ';')
		RETURN(';');
	if (c == '}') {
		d = inputc();
		while (d == ' ' || d == '\t')
			d = inputc();
		if (d == '\n')
			lineno++;
		else
			unputc(d);
		state = SC;
		RETURN(';');
	}
	if (c == '"')
		return(readstr());
	if (c == '$') {
		d = inputc();
		while (d == ' ' || d == '\t')
			d = inputc();
		if (isdigit(d)) {
			n = 0;
			do {
				n = n * 10 + d - '0';
				d = inputc();
			} while (isdigit(d));
			unputc(d);
			if (n == 0) {
				yylval = (int)lookup("$record", symtab);
				RETURN(STRING);
			}
			yylval = (int)fieldadr(n);
			RETURN(FIELD);
		}
		unputc(d);
		RETURN(INDIRECT);
	}
	if (isdigit(c) || c == '.') {
		n = 0;
		do {
			if (n < CBUFLEN-1)
				buf[n++] = c;
			c = inputc();
		} while (isdigit(c) || c == '.');
		if (c == 'e' || c == 'E') {
			if (n < CBUFLEN-1)
				buf[n++] = c;
			c = inputc();
			if (c == '+' || c == '-') {
				if (n < CBUFLEN-1)
					buf[n++] = c;
				c = inputc();
			}
			while (isdigit(c)) {
				if (n < CBUFLEN-1)
					buf[n++] = c;
				c = inputc();
			}
		}
		buf[n] = 0;
		unputc(c);
		if (n == 1 && buf[0] == '.') {
			yylval = '.';
			RETURN('.');
		}
		yylval = (int)setsymtab(buf, NULL, atof(buf), CON|NUM, symtab);
		RETURN(NUMBER);
	}
	if (isword1(c)) {
		n = 0;
		do {
			if (n < CBUFLEN-1)
				buf[n++] = c;
			c = inputc();
		} while (isword(c));
		buf[n] = 0;
		unputc(c);
		if (word(buf, "BEGIN")) RETURN(XBEGIN);
		if (word(buf, "END")) RETURN(XEND);
		if (word(buf, "PROGEND")) return(0);
		if (word(buf, "while")) RETURN(WHILE);
		if (word(buf, "for")) RETURN(FOR);
		if (word(buf, "if")) RETURN(IF);
		if (word(buf, "else")) RETURN(ELSE);
		if (word(buf, "next")) RETURN(NEXT);
		if (word(buf, "exit")) RETURN(EXIT);
		if (word(buf, "break")) RETURN(BREAK);
		if (word(buf, "continue")) RETURN(CONTINUE);
		if (word(buf, "print")) { yylval = PRINT; RETURN(PRINT); }
		if (word(buf, "printf")) { yylval = PRINTF; RETURN(PRINTF); }
		if (word(buf, "sprintf")) { yylval = SPRINTF; RETURN(SPRINTF); }
		if (word(buf, "split")) { yylval = SPLIT; RETURN(SPLIT); }
		if (word(buf, "substr")) RETURN(SUBSTR);
		if (word(buf, "index")) RETURN(INDEX);
		if (word(buf, "in")) RETURN(IN);
		if (word(buf, "length")) { yylval = FLENGTH; RETURN(FNCN); }
		if (word(buf, "log")) { yylval = FLOG; RETURN(FNCN); }
		if (word(buf, "int")) { yylval = FINT; RETURN(FNCN); }
		if (word(buf, "exp")) { yylval = FEXP; RETURN(FNCN); }
		if (word(buf, "sqrt")) { yylval = FSQRT; RETURN(FNCN); }
		if (word(buf, "NF"))
			mustfld = 1;
		yylval = (int)setsymtab(buf, NULL, 0.0, NUM, symtab);
		RETURN(VAR);
	}

	d = inputc();
	switch (c) {
	case '|':
		if (d == '|') RETURN(BOR);
		break;
	case '&':
		if (d == '&') RETURN(AND);
		break;
	case '!':
		if (d == '=') { yylval = NE; RETURN(RELOP); }
		if (d == '~') { yylval = NOTMATCH; RETURN(MATCHOP); }
		yylval = NOT;
		unputc(d);
		RETURN(NOT);
	case '~':
		yylval = MATCH;
		unputc(d);
		RETURN(MATCHOP);
	case '<':
		if (d == '=') { yylval = LE; RETURN(RELOP); }
		yylval = LT;
		unputc(d);
		RETURN(RELOP);
	case '>':
		if (d == '=') { yylval = GE; RETURN(RELOP); }
		if (d == '>') { yylval = APPEND; RETURN(RELOP); }
		yylval = GT;
		unputc(d);
		RETURN(RELOP);
	case '=':
		if (d == '=') { yylval = EQ; RETURN(RELOP); }
		yylval = ASSIGN;
		unputc(d);
		RETURN(ASGNOP);
	case '+':
		if (d == '+') { yylval = INCR; RETURN(INCR); }
		if (d == '=') { yylval = ADDEQ; RETURN(ASGNOP); }
		break;
	case '-':
		if (d == '-') { yylval = DECR; RETURN(DECR); }
		if (d == '=') { yylval = SUBEQ; RETURN(ASGNOP); }
		break;
	case '*':
		if (d == '=') { yylval = MULTEQ; RETURN(ASGNOP); }
		break;
	case '/':
		if (d == '=') { yylval = DIVEQ; RETURN(ASGNOP); }
		break;
	case '%':
		if (d == '=') { yylval = MODEQ; RETURN(ASGNOP); }
		break;
	}
	unputc(d);
	yylval = c;
	RETURN(c);
}

int
startreg()
{
	state = REG;
	return(0);
}
