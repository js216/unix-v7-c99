#ifndef PWD_H
#define PWD_H
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

extern struct passwd *getpwent(void);
extern struct passwd *getpwnam(char *);
extern struct passwd *getpwuid(int);
extern void setpwent(void);
extern void endpwent(void);
#endif
