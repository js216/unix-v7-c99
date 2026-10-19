struct	passwd { /* see getpwent(3) */
	char	*pw_name;
	char	*pw_passwd;
	int	pw_uid;
	int	pw_gid;
	int	pw_quota;
	char	*pw_comment;
	char	*pw_gecos;
	char	*pw_dir;
	char	*pw_shell;
};
struct	passwd	*getpwent(void), *getpwuid(int uid),
    *getpwnam(char *name);
void	setpwent(void), endpwent(void);
