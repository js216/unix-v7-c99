/*
 * Compare strings:  s1>s2: >0  s1==s2: 0  s1<s2: <0
 *
 * Ported from v7/usr/src/libc/gen/strcmp.c.
 */

int
strcmp(char *s1, char *s2)
{

	while(*s1 == *s2++)
		if(*s1++ == '\0')
			return(0);
	return(*s1 - *--s2);
}
