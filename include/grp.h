#ifndef GRP_H
#define GRP_H
struct	group { /* see getgrent(3) */
	char	*gr_name;
	char	*gr_passwd;
	int	gr_gid;
	char	**gr_mem;
};
extern struct group *getgrent(void);
extern struct group *getgrgid(int gid);
extern struct group *getgrnam(char *name);
extern void setgrent(void);
extern void endgrent(void);
#endif
