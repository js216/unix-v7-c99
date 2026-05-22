/* wc line, word, char, and longest-line count */

#include <stdio.h>

void wcp(register char *wd, long charct, long wordct, long linect, long longest);

int
main(int argc, char *argv[])
{
	int i, token;
	register FILE *fp;
	long linect, wordct, charct, longest, curline;
	long tlinect=0, twordct=0, tcharct=0, tlongest=0;
	char *wd;
	register int c;

	wd = "lwc";
	if(argc > 1 && *argv[1] == '-') {
		wd = ++argv[1];
		argc--;
		argv++;
	}

	i = 1;
	fp = stdin;
	do {
		if(argc>1 && (fp=fopen(argv[i], "r")) == NULL) {
			fprintf(stderr, "wc: can't open %s\n", argv[i]);
			continue;
		}
		linect = 0;
		wordct = 0;
		charct = 0;
		longest = 0;
		curline = 0;
		token = 0;
		for(;;) {
			c = getc(fp);
			if (c == EOF)
				break;
			charct++;
			if(c == '\n') {
				if (curline > longest) longest = curline;
				curline = 0;
			} else {
				curline++;
			}
			if(' '<c&&c<0177) {
				if(!token) {
					wordct++;
					token++;
				}
				continue;
			}
			if(c=='\n')
				linect++;
			else if(c!=' '&&c!='\t')
				continue;
			token = 0;
		}
		if (curline > longest) longest = curline;
		/* print lines, words, chars */
		wcp(wd, charct, wordct, linect, longest);
		if(argc>1) {
			printf(" %s\n", argv[i]);
		} else
			printf("\n");
		fclose(fp);
		tlinect += linect;
		twordct += wordct;
		tcharct += charct;
		if (longest > tlongest) tlongest = longest;
	} while(++i<argc);
	if(argc > 2) {
		wcp(wd, tcharct, twordct, tlinect, tlongest);
		printf(" total\n");
	}
	exit(0);
}

void
wcp(register char *wd, long charct, long wordct, long linect, long longest)
{
	while (*wd) switch (*wd++) {
	case 'l':
		printf("%7ld", linect);
		break;

	case 'w':
		printf("%7ld ", wordct);
		break;

	case 'c':
		printf("%7ld", charct);
		break;

	case 'L':
		printf("%7ld", longest);
		break;
	}
}
