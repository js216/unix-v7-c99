#include "stdio.h"
#include "awk.h"
struct tok
{	char *tnm;
	int yval;
} tok[]	= {
{"FIRSTTOKEN", 258},
{"FINAL", 259},
{"FATAL", 260},
{"LT", 261},
{"LE", 262},
{"GT", 263},
{"GE", 264},
{"EQ", 265},
{"NE", 266},
{"MATCH", 267},
{"NOTMATCH", 268},
{"APPEND", 269},
{"ADD", 270},
{"MINUS", 271},
{"MULT", 272},
{"DIVIDE", 273},
{"MOD", 274},
{"UMINUS", 275},
{"ASSIGN", 276},
{"ADDEQ", 277},
{"SUBEQ", 278},
{"MULTEQ", 279},
{"DIVEQ", 280},
{"MODEQ", 281},
{"JUMP", 282},
{"XBEGIN", 283},
{"XEND", 284},
{"NL", 285},
{"PRINT", 286},
{"PRINTF", 287},
{"SPRINTF", 288},
{"SPLIT", 289},
{"IF", 290},
{"ELSE", 291},
{"WHILE", 292},
{"FOR", 293},
{"IN", 294},
{"NEXT", 295},
{"EXIT", 296},
{"BREAK", 297},
{"CONTINUE", 298},
{"PROGRAM", 299},
{"PASTAT", 300},
{"PASTAT2", 301},
{"ASGNOP", 302},
{"BOR", 303},
{"AND", 304},
{"NOT", 305},
{"NUMBER", 306},
{"VAR", 307},
{"ARRAY", 308},
{"FNCN", 309},
{"SUBSTR", 310},
{"LSUBSTR", 311},
{"INDEX", 312},
{"RELOP", 313},
{"MATCHOP", 314},
{"OR", 315},
{"STRING", 316},
{"DOT", 317},
{"CCL", 318},
{"NCCL", 319},
{"CHAR", 320},
{"CAT", 321},
{"STAR", 322},
{"PLUS", 323},
{"QUEST", 324},
{"POSTINCR", 325},
{"PREINCR", 326},
{"POSTDECR", 327},
{"PREDECR", 328},
{"INCR", 329},
{"DECR", 330},
{"FIELD", 331},
{"INDIRECT", 332},
{"LASTTOKEN", 333},
};
int
ptoken(int n)
{
	if(n<128) printf("lex: %c\n",n);
	else	if(n<=256) printf("lex:? %o\n",n);
	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-FIRSTTOKEN].tnm);
	else	printf("lex:? %o\n",n);
	return(0);
}

char *tokname(int n)
{
	if (n<=256 || n >= LASTTOKEN)
		n = 257;
	return(tok[n-FIRSTTOKEN].tnm);
}
