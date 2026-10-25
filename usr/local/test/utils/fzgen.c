/*
 * fzgen seed lines n	n lines of 0 to 8 words from a small vocabulary
 * fzgen seed ints n	n integers below 10000, one to a line
 * fzgen seed num lo hi	one integer from lo to hi
 * The same seed always gives the same output.
 */

#include <stdio.h>

char	*word[] = {
	"a", "an", "apple", "banana", "cherry", "date", "e", "ee", "fig",
	"grape", "kiwi", "lemon", "mango", "x", "xx", "zzzzzzzzzzzzzzzzzzzz",
};
#define	NWORD	(sizeof(word)/sizeof(word[0]))
unsigned long	rs;

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

int
main(int argc, char **argv)
{
	int i, j, n;
	long lo;

	if(argc < 4) {
		printf("usage: fzgen seed lines|ints|num ...\n");
		exit(2);
	}
	rs = atol(argv[1])*2654435761UL + 3;
	n = atoi(argv[3]);
	if(strcmp(argv[2], "lines") == 0)
		for(i = 0; i < n; i++) {
			for(j = rnd(9); j > 0; j--)
				printf("%s%s", word[rnd(NWORD)], j > 1 ? " " : "");
			printf("\n");
		}
	else if(strcmp(argv[2], "ints") == 0)
		for(i = 0; i < n; i++)
			printf("%u\n", rnd(10000));
	else if(strcmp(argv[2], "num") == 0 && argc == 5) {
		lo = atol(argv[3]);
		printf("%ld\n", lo + rnd((unsigned)(atol(argv[4]) - lo + 1)));
	} else {
		printf("fzgen: bad kind %s\n", argv[2]);
		exit(2);
	}
	exit(0);
}
