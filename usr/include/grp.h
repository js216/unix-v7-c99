struct	group { /* see getgrent(3) */
	char	*gr_name;
	char	*gr_passwd;
	int	gr_gid;
	char	**gr_mem;
};
struct	group	*getgrent(void), *getgrgid(int gid),
    *getgrnam(char *name);
void	setgrent(void), endgrent(void);
