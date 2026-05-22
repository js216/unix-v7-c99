#include "stdio.h"
#include "awk.def"
#include "awk.h"
int logit(), syminit(), run(), msgfiles(), error(), yyparse();

int	dbg	= 0;
int	svargc;
char	**svargv, **xargv;
extern FILE	*yyin;	/* lex input file */
char	*lexprog;	/* points to program argument if it exists */
extern int	errorflag;	/* non-zero if any syntax errors; set by yyerror */

int filefd, iflag, symnum, ansfd;
char *filelist;
extern int maxsym, errno;
char lexbuf[512];

int
haschar(char *s, int c)
{
	while (*s)
		if (*s++ == c)
			return(1);
	return(0);
}

int
kwstart(char *s, char *kw)
{
	while (*kw)
		if (*s++ != *kw++)
			return(0);
	return(*s == 0 || *s == '{' || *s == ' ' || *s == '\t');
}

int
awkcmdstart(char *s)
{
	return(*s == '{' || kwstart(s, "BEGIN") || kwstart(s, "END"));
}

int
awkcmdnext(char *s)
{
	return(kwstart(s, "BEGIN") || kwstart(s, "END"));
}

int
awkcmdnextact(int argc, char *argv[], int i)
{
	if (i >= argc || !awkcmdnext(argv[i]))
		return(0);
	if (haschar(argv[i], '{'))
		return(1);
	return(i + 1 < argc && argv[i+1][0] == '{');
}

int
awkcmdsplit(int argc, char *argv[])
{
	char *p;
	int braces, sawbrace, i;

	if (!awkcmdstart(argv[0]))
		return(0);
	braces = 0;
	sawbrace = 0;
	for (i = 0; i < argc; i++) {
		for (p = argv[i]; *p; p++) {
			if (*p == '{') {
				braces++;
				sawbrace = 1;
			} else if (*p == '}') {
				braces--;
			}
		}
		if (sawbrace && braces <= 0) {
			if (awkcmdnextact(argc, argv, i+1))
				continue;
			return(i != 0);
		}
	}
	return(0);
}

int
main(int argc, char *argv[]) {
	if (argc == 1)
		error(FATAL, "Usage: awk [-f source | 'cmds'] [files]");
	if (strcmp(argv[0], "a.out"))
		logit(argc, argv);
	syminit();
	while (argc > 1) {
		argc--;
		argv++;
		if (argv[0][0] == '-' && argv[0][1] == 'f') {
			yyin = fopen(argv[1], "r");
			if (yyin == NULL)
				error(FATAL, "can't open %s", argv[1]);
			argc--;
			argv++;
			break;
		} else if (argv[0][0] == '-' && argv[0][1] == 'F') {	/* set field sep */
			if (argv[0][2] == 't')	/* special case for tab */
				**FS = '\t';
			else
				**FS = argv[0][2];
			continue;
		} else if (argv[0][0] != '-') {
			dprintf("cmds=|%s|\n", argv[0], NULL, NULL);
			yyin = NULL;
			lexprog = argv[0];
			if (awkcmdsplit(argc, argv)) {
				char *cmdname;
				char *p;
				int braces, n, sawbrace, wantact;

				cmdname = argv[-1];
				p = lexbuf;
				braces = 0;
				n = 0;
				sawbrace = 0;
				wantact = 0;
				while (argc > 0) {
					char *q;

					if (n++ != 0 && p < &lexbuf[sizeof(lexbuf)-1])
						*p++ = ' ';
					if (awkcmdnext(argv[0]))
						wantact = 1;
					for (q = argv[0]; *q && p < &lexbuf[sizeof(lexbuf)-1]; q++) {
						if (*q == '{') {
							braces++;
							sawbrace = 1;
							wantact = 0;
						} else if (*q == '}')
							braces--;
						*p++ = *q;
					}
					argc--;
					if (sawbrace && braces <= 0 && !wantact &&
					    !awkcmdnextact(argc + 1, argv, 1))
						break;
					argv++;
				}
				*p = 0;
				lexprog = lexbuf;
				argc++;
				argv[0] = cmdname;
			}
			else
				argv[0] = argv[-1];	/* need this space */
			break;
		} else if (strcmp("-d", argv[0])==0)
			dbg = 1;
		else if (argv[0][0]=='-' && argv[0][1]=='i') {
			iflag=1;
			sscanf(argv[0], "-i%d, %d", &filefd, &ansfd);
		}
	}
	if (argc <= 1 && !iflag) {
		argv[0][0] = '-';
		argv[0][1] = '\0';
		argc++;
		argv--;
	}
	if (!iflag) {
		svargc = --argc;
		svargv = ++argv;
		dprintf("svargc=%d svargv[0]=%s\n", svargc, svargv[0], NULL);
	}
	*FILENAME = *svargv;	/* initial file name */
iloop:
	if (iflag)
		msgfiles();
	yyparse();
	dprintf("errorflag=%d\n", errorflag, NULL, NULL);
	if (errorflag)
		exit(0);
	run();
	if (iflag)
		write(ansfd, (char *)&errorflag, sizeof(errorflag));
	else exit(errorflag);
/*sym cleanup should go here , followed by another syminit*/
	goto iloop;
}

int
logit(int n, char *s[])
{	int i, tvec[2];
	FILE *f, *g;
	char buf[512];
	if ((f=fopen("/usr/pjw/awk/awkhist", "a"))==NULL)
		return(0);
	time((long *)tvec);
	fprintf(f, "%-8s %s", getlogin(), ctime((long *)tvec));
	for (i=0; i<n; i++)
		fprintf(f, "'%s'", s[i]);
	putc('\n', f);
	if (strcmp(s[1], "-f")) {
		fclose(f);
		return(0);
	}
	if ((g=fopen(s[2], "r"))==NULL) {
		fclose(f);
		return(0);
	}
	while ((i=fread(buf, 1, 512, g))>0)
		fwrite(buf, 1, i, f);
	fclose(f);
	fclose(g);
	return(0);
}

int
yywrap(void)
{
	return(1);
}

int
msgfiles(void)
{	char buf[512], *p, *q, **s;
	int n;
	n=read(filefd, buf, 512);
	if (n<=0)	/*no one at other end?*/ {
		perror("no files");
		exit(errno);
	}
	xfree(filelist);
	q=filelist=malloc(n);
	for (p=buf; *p==' ' || *p=='\t' || *p=='\n'; p++); 
	for (n=0; *p!=';'; )
	{
		if (*p==' ' || *p=='\t' || *p=='\n') {
			n++;
			*q++=0;
			while (*p==' ' || *p=='\t' || *p=='\n')
				p++;
		}
		else	*q++ = *p++;
	}
	if (q!=filelist && *(q-1)!=0) {
		n++;
		*q++ = 0;
	}
	svargc=n;
	xfree(xargv);
	xargv=s=svargv=(char **)malloc(n*sizeof(char *));
	for (p=filelist; n>0; n--)
	{
		*s++=p;
		while (*p++ != 0);
	}
	return(0);
}
