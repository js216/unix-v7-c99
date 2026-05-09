#include "../lib/u.h"

/*
 * login: read a username + password and set uid/gid by walking
 * /etc/passwd.  Each colon-separated record is name:hash:uid:gid:...;
 * we only need name and uid here -- password checking is wired up
 * but accepts an empty stored hash, which is what /etc/passwd ships
 * with on this image.
 */

static char name[32];
static char password[32];
static char buf[1024];

static void
getline(char *out, int n, int echo)
{
	int i;
	char c;

	i = 0;
	while(i < n-1) {
		if(read(0, &c, 1) != 1)
			break;
		if(c == '\n')
			break;
		out[i++] = c;
		(void)echo;
	}
	out[i] = 0;
	puts("\n");
}

static int
streq(char *a, char *b)
{

	while(*a && *b && *a == *b) { a++; b++; }
	return(*a == 0 && *b == 0);
}

static int
lookup(char *user, char **storedhash, int *uid_out)
{
	int fd, n, i;
	char *p, *q, *line_start;
	static char hash[32];
	char field_buf[32];
	int uid;
	fd = open("/etc/passwd", 0);
	if(fd < 0)
		return(0);
	n = read(fd, buf, sizeof(buf) - 1);
	(void)close(fd);
	if(n <= 0)
		return(0);
	buf[n] = 0;

	p = buf;
	while(*p) {
		line_start = p;
		while(*p && *p != '\n')
			p++;
		if(*p) { *p = 0; p++; }

		/* name */
		q = line_start;
		i = 0;
		while(*q && *q != ':' && i < (int)sizeof(field_buf)-1)
			field_buf[i++] = *q++;
		field_buf[i] = 0;
		if(!streq(field_buf, user))
			continue;
		if(*q != ':')
			continue;
		q++;
		/* hash */
		i = 0;
		while(*q && *q != ':' && i < (int)sizeof(hash)-1)
			hash[i++] = *q++;
		hash[i] = 0;
		if(*q != ':')
			continue;
		q++;
		/* uid */
		uid = 0;
		while(*q >= '0' && *q <= '9') {
			uid = uid*10 + (*q - '0');
			q++;
		}
		*storedhash = hash;
		*uid_out = uid;
		(void)field_buf;
		return(1);
	}
	return(0);
}

int
main(void)
{
	char *hash;
	int uid;

	getline(name, sizeof(name), 1);
	if(name[0] == 0) {
		puts("login incorrect");
		return(1);
	}
	if(!lookup(name, &hash, &uid)) {
		puts("login incorrect");
		return(1);
	}
	if(hash[0]) {
		puts("Password: ");
		getline(password, sizeof(password), 0);
		/* Stored is plaintext for the test image; real V7 hashes
		 * its passwd entries with crypt(3). */
		if(!streq(password, hash)) {
			puts("login incorrect");
			return(1);
		}
	}
	(void)setuid(uid);
	(void)exec("/bin/sh");
	puts("login: no shell");
	return(1);
}
