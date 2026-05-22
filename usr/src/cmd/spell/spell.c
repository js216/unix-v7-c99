#define unix 1
#include "spell.h"
#define DLEV 2

char	*strcat();
int	strip();
char	*skipv();
int	an();
int	s();
int	es();
int	ily();
int	ncy();
int	CCe();
int	VCe();
int	bility();
int	tion();
int	ize();
int	y_to_e();
int	i_to_y();
int	nop();
int	metry();

struct suftab {
	char *suf;
	int (*p1)();
	int n1;
	char *d1;
	char *a1;
	int (*p2)();
	int n2;
	char *d2;
	char *a2;
} suftab[] = {
	{"ssen",ily,4,"-y+iness","+ness",	0, 0, "", ""},
	{"ssel",ily,4,"-y+i+less","+less",	0, 0, "", ""},
	{"se",s,1,"","+s",		es,2,"-y+ies","+es" },
	{"s'",s,2,"","+'s",		0, 0, "", ""},
	{"s",s,1,"","+s",		0, 0, "", ""},
	{"ecn",ncy,1,"","-t+ce",		0, 0, "", ""},
	{"ycn",ncy,1,"","-cy+t",		0, 0, "", ""},
	{"ytilb",nop,0,"","",		0, 0, "", ""},
	{"ytilib",bility,5,"-le+ility","",		0, 0, "", ""},
	{"elbaif",i_to_y,4,"-y+iable","",		0, 0, "", ""},
	{"elba",CCe,4,"-e+able","+able",		0, 0, "", ""},
	{"yti",CCe,3,"-e+ity","+ity",		0, 0, "", ""},
	{"ylb",y_to_e,1,"-e+y","",		0, 0, "", ""},
	{"yl",ily,2,"-y+ily","+ly",		0, 0, "", ""},
	{"laci",strip,2,"","+al",		0, 0, "", ""},
	{"latnem",strip,2,"","+al",		0, 0, "", ""},
	{"lanoi",strip,2,"","+al",		0, 0, "", ""},
	{"tnem",strip,4,"","+ment",		0, 0, "", ""},
	{"gni",CCe,3,"-e+ing","+ing",		0, 0, "", ""},
	{"reta",nop,0,"","",		0, 0, "", ""},
	{"re",strip,1,"","+r",		i_to_y,2,"-y+ier","+er"},
	{"de",strip,1,"","+d",		i_to_y,2,"-y+ied","+ed"},
	{"citsi",strip,2,"","+ic",		0, 0, "", ""},
	{"cihparg",i_to_y,1,"-y+ic","",		0, 0, "", ""},
	{"tse",strip,2,"","+st",	i_to_y,3,"-y+iest","+est"},
	{"cirtem",i_to_y,1,"-y+ic","",		0, 0, "", ""},
	{"yrtem",metry,0,"-ry+er","",		0, 0, "", ""},
	{"cigol",i_to_y,1,"-y+ic","",		0, 0, "", ""},
	{"tsigol",i_to_y,2,"-y+ist","",		0, 0, "", ""},
	{"tsi",VCe,3,"-e+ist","+ist",		0, 0, "", ""},
	{"msi",VCe,3,"-e+ism","+ist",		0, 0, "", ""},
	{"noitacif",i_to_y,6,"-y+ication","",		0, 0, "", ""},
	{"noitazi",ize,5,"-e+ation","",		0, 0, "", ""},
	{"rota",tion,2,"-e+or","",		0, 0, "", ""},
	{"noit",tion,3,"-e+ion","+ion",		0, 0, "", ""},
	{"naino",an,3,"","+ian",		0, 0, "", ""},
	{"na",an,1,"","+n",		0, 0, "", ""},
	{"evit",tion,3,"-e+ive","+ive",		0, 0, "", ""},
	{"ezi",CCe,3,"-e+ize","+ize",		0, 0, "", ""},
	{"pihs",strip,4,"","+ship",		0, 0, "", ""},
	{"dooh",ily,4,"-y+ihood","+hood",		0, 0, "", ""},
	{"luf",ily,3,"-y+iful","+ful",		0, 0, "", ""},
	{"ekil",strip,4,"","+like",		0, 0, "", ""},
	{0, 0, 0, 0, 0, 0, 0, 0, 0}
};

char *preftab[] = {
	"anti",
	"bio",
	"dis",
	"electro",
	"en",
	"fore",
	"hyper",
	"intra",
	"inter",
	"iso",
	"kilo",
	"magneto",
	"meta",
	"micro",
	"milli",
	"mis",
	"mono",
	"multi",
	"non",
	"out",
	"over",
	"photo",
	"poly",
	"pre",
	"pseudo",
	"re",
	"semi",
	"stereo",
	"sub",
	"super",
	"thermo",
	"ultra",
	"under",	/*must precede un*/
	"un",
	0
};

int vflag;
int xflag;
char word[100];
char original[100];
char *deriv[40];
char affix[40];

int suffix(), strip(), putsuf(), putw(), monosyl(), vowel(),
    ise(), ztos(), dict();

int
main(int argc, char **argv)
{
	register char *ep, *cp;
	register char *dp;
	int fold;
	int j;
	FILE *file, *found;
	if(!prime(argc,argv)) {
		fprintf(stderr,
		    "spell: cannot initialize hash table\n");
		exit(1);
	}
	found = fopen(argv[2],"w");
	for(argc-=3,argv+=3; argc>0 && argv[0][0]=='-'; argc--,argv++)
		switch(argv[0][1]) {
		case 'b':
			ise();
			break;
		case 'v':
			vflag++;
			break;
		case 'x':
			xflag++;
			break;
		}
	for(;; fprintf(file,"%s%s\n",affix,original)) {
		affix[0] = 0;
		file = found;
		for(ep=word;(*ep=j=getchar())!='\n';ep++)
			if(j == EOF)
				exit(0);
		for(cp=word,dp=original; cp<ep; )
			*dp++ = *cp++;
		*dp = 0;
		fold = 0;
		for(cp=word;cp<ep;cp++)
			if(islower(*cp))
				goto lcase;
		if(putsuf(ep,".",0))
			continue;
		++fold;
		for(cp=original+1,dp=word+1;dp<ep;dp++,cp++)
			*dp = Tolower(*cp);
lcase:
		if(putsuf(ep,".",0)||suffix(ep,0))
			continue;
		if(isupper(word[0])) {
			for(cp=original,dp=word; (*dp = *cp++); dp++)
				if (fold) *dp = Tolower(*dp);
			word[0] = Tolower(word[0]);
			goto lcase;
		}
		file = stdout;
	}
}

int
suffix(char *ep, int lev)
{
	register struct suftab *t;
	register char *cp, *sp;
	lev += DLEV;
	deriv[lev] = deriv[lev-1] = 0;
	for(t= &suftab[0];(sp=t->suf);t++) {
		cp = ep;
		while(*sp)
			if(*--cp!=*sp++)
				goto next;
		for(sp=cp; --sp>=word&&!vowel(*sp); ) ;
		if(sp<word)
			return(0);
		if((*t->p1)(ep-t->n1,t->d1,t->a1,lev+1))
			return(1);
		if(t->p2!=0) {
			deriv[lev] = deriv[lev+1] = 0;
			return((*t->p2)(ep-t->n2,t->d2,t->a2,lev));
		}
		return(0);
next:		;
	}
	return(0);
}

int
nop(void)
{
	return(0);
}

int
strip(char *ep, char *d, char *a, int lev)
{
	(void)d;
	return(putsuf(ep,a,lev)||suffix(ep,lev));
}

int
s(char *ep, char *d, char *a, int lev)
{
	if(lev>DLEV+1)
		return(0);
	if(*ep=='s'&&ep[-1]=='s')
		return(0);
	return(strip(ep,d,a,lev));
}

int
an(char *ep, char *d, char *a, int lev)
{
	(void)d;
	if(!isupper(*word))	/*must be proper name*/
		return(0);
	return(putsuf(ep,a,lev));
}

int
ize(char *ep, char *d, char *a, int lev)
{
	(void)a;
	*ep++ = 'e';
	return(strip(ep,"",d,lev));
}

int
y_to_e(char *ep, char *d, char *a, int lev)
{
	(void)a;
	*ep++ = 'e';
	return(strip(ep,"",d,lev));
}

int
ily(char *ep, char *d, char *a, int lev)
{
	if(ep[-1]=='i')
		return(i_to_y(ep,d,a,lev));
	else
		return(strip(ep,d,a,lev));
}

int
ncy(char *ep, char *d, char *a, int lev)
{
	if(skipv(skipv(ep-1))<word)
		return(0);
	ep[-1] = 't';
	return(strip(ep,d,a,lev));
}

int
bility(char *ep, char *d, char *a, int lev)
{
	*ep++ = 'l';
	return(y_to_e(ep,d,a,lev));
}

int
i_to_y(char *ep, char *d, char *a, int lev)
{
	if(ep[-1]=='i') {
		ep[-1] = 'y';
		a = d;
	}
	return(strip(ep,"",a,lev));
}

int
es(char *ep, char *d, char *a, int lev)
{
	if(lev>DLEV)
		return(0);
	switch(ep[-1]) {
	default:
		return(0);
	case 'i':
		return(i_to_y(ep,d,a,lev));
	case 's':
	case 'h':
	case 'z':
	case 'x':
		return(strip(ep,d,a,lev));
	}
}

int
metry(char *ep, char *d, char *a, int lev)
{
	ep[-2] = 'e';
	ep[-1] = 'r';
	return(strip(ep,d,a,lev));
}

int
tion(char *ep, char *d, char *a, int lev)
{
	switch(ep[-2]) {
	case 'c':
	case 'r':
		return(putsuf(ep,a,lev));
	case 'a':
		return(y_to_e(ep,d,a,lev));
	}
	return(0);
}

/*	possible consonant-consonant-e ending*/
int
CCe(char *ep, char *d, char *a, int lev)
{
	switch(ep[-1]) {
	case 'l':
		if(vowel(ep[-2]))
			break;
		switch(ep[-2]) {
		case 'l':
		case 'r':
		case 'w':
			break;
		default:
			return(y_to_e(ep,d,a,lev));
		}
		break;
	case 's':
		if(ep[-2]=='s')
			break;
		/* fallthrough */
	case 'c':
	case 'g':
		if(*ep=='a')
			return(0);
		/* fallthrough */
	case 'v':
	case 'z':
		if(vowel(ep[-2]))
			break;
		/* fallthrough */
	case 'u':
		if(y_to_e(ep,d,a,lev))
			return(1);
		if(!(ep[-2]=='n'&&ep[-1]=='g'))
			return(0);
	}
	return(VCe(ep,d,a,lev));
}

/*	possible consonant-vowel-consonant-e ending*/
int
VCe(char *ep, char *d, char *a, int lev)
{
	char c;
	c = ep[-1];
	if(c=='e')
		return(0);
	if(!vowel(c) && vowel(ep[-2])) {
		c = *ep;
		*ep++ = 'e';
		if(putsuf(ep,d,lev)||suffix(ep,lev))
			return(1);
		ep--;
		*ep = c;
	}
	return(strip(ep,d,a,lev));
}

char *
lookuppref(char **wp, char *ep)
{
	register char **sp;
	register char *bp,*cp;
	for(sp=preftab;*sp;sp++) {
		bp = *wp;
		for(cp= *sp;*cp;cp++,bp++)
			if(Tolower(*bp)!=*cp)
				goto next;
		for(cp=bp;cp<ep;cp++) 
			if(vowel(*cp)) {
				*wp = bp;
				return(*sp);
			}
next:	;
	}
	return(0);
}

int
putsuf(char *ep, char *a, int lev)
{
	register char *cp;
	char *bp;
	register char *pp;
	int val = 0;
	char space[20];
	deriv[lev] = a;
	if(putw(word,ep,lev))
		return(1);
	bp = word;
	pp = space;
	deriv[lev+1] = pp;
	while((cp=lookuppref(&bp,ep))) {
		*pp++ = '+';
		while((*pp = *cp++))
			pp++;
		if(putw(bp,ep,lev+1)) {
			val = 1;
			break;
		}
	}
	deriv[lev+1] = deriv[lev+2] = 0;
	return(val);
}

int
putw(char *bp, char *ep, int lev)
{
	register int i, j;
	char duple[3];
	if(ep-bp<=1)
		return(0);
	if(vowel(*ep)) {
		if(monosyl(bp,ep))
			return(0);
	}
	i = dict(bp,ep);
	if(i==0&&vowel(*ep)&&ep[-1]==ep[-2]&&monosyl(bp,ep-1)) {
		ep--;
		deriv[++lev] = duple;
		duple[0] = '+';
		duple[1] = *ep;
		duple[2] = 0;
		i = dict(bp,ep);
	}
	if(vflag==0||i==0)
		return(i);
	j = lev;
	do {
		if(deriv[j])
			strcat(affix,deriv[j]);
	} while(--j>0);
	strcat(affix,"\t");
	return(i);
}


int
monosyl(char *bp, char *ep)
{
	if(ep<bp+2)
		return(0);
	if(vowel(*--ep)||!vowel(*--ep)
		||ep[1]=='x'||ep[1]=='w')
		return(0);
	while(--ep>=bp)
		if(vowel(*ep))
			return(0);
	return(1);
}

char *
skipv(char *s)
{
	if(s>=word&&vowel(*s))
		s--;
	while(s>=word&&!vowel(*s))
		s--;
	return(s);
}

int
vowel(int c)
{
	switch(Tolower(c)) {
	case 'a':
	case 'e':
	case 'i':
	case 'o':
	case 'u':
	case 'y':
		return(1);
	}
	return(0);
}

/* crummy way to Britishise */
int
ise(void)
{
	register struct suftab *p;
	for(p = suftab;p->suf;p++) {
		ztos(p->suf);
		ztos(p->d1);
		ztos(p->a1);
	}
	return(0);
}
int
ztos(char *s)
{
	for(;*s;s++)
		if(*s=='z')
			*s = 's';
	return(0);
}

int
dict(char *bp, char *ep)
{
	register char *wp;
	long h;
	register long *lp;
	register int i;
	if(xflag)
		printf("=%.*s\n",ep-bp,bp);
	for(i=0; i<(int)NP; i++) {
		for (wp = bp, h = 0, lp = pow2[i]; wp < ep; ++wp, ++lp)
			h += *wp * *lp;
		h += '\n' * *lp;
		h %= p[i];
		if(get(h)==0)
			return(0);
	}
	return(1);
}
