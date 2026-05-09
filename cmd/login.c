/*
 * login [ name ]
 *
 * Ported from v7/usr/src/cmd/login.c with K&R -> C99 prototype
 * conversions, type widening (16-bit `int` on PDP-11 -> 32-bit on
 * Armv7), `register` removed, and explicit `void` returns added
 * where the v7 source falls off the end.  Algorithm and order of
 * operations are unchanged.  Some libc helpers it leans on
 * (ttyname, ttyslot, mail spool stat, /usr/adm/wtmp, motd) are
 * mostly stubs in this port; their absence shows up only as
 * skipped accounting, never as a behavioural change.
 */

#include <sys/types.h>
#include <sgtty.h>
#include <utmp.h>
#include <signal.h>
#include <pwd.h>
#include <stdio.h>
#include <sys/stat.h>
#define SCPYN(a, b)	strncpy(a, b, sizeof(a))

static int stopmotd;

static void catch(int sig);
static void showmotd(void);

char	maildir[30] =	"/usr/spool/mail/";
struct	passwd nouser = {"", "nope"};
struct	sgttyb ttyb;
struct	utmp utmp;
char	minusnam[16] = "-";
char	homedir[64] = "HOME=";
char	*envinit[] = {homedir, "PATH=:/bin:/usr/bin", 0};
struct	passwd *pwd;

int
main(int argc, char **argv)
{
	char *namep;
	int t, f, c;
	char *ttyn;

	(void)alarm(60);
	(void)signal(SIGQUIT, (int)SIG_IGN);
	(void)signal(SIGINT, (int)SIG_IGN);
	(void)nice(-100);
	(void)nice(20);
	(void)nice(0);
	(void)gtty(0, &ttyb);
	ttyb.sg_erase = '#';
	ttyb.sg_kill = '@';
	(void)stty(0, &ttyb);
	for(t = 3; t < 20; t++)
		(void)close(t);
	ttyn = ttyname(0);
	if(ttyn == 0)
		ttyn = "/dev/tty??";

loop:
	SCPYN(utmp.ut_name, "");
	if(argc > 1) {
		SCPYN(utmp.ut_name, argv[1]);
		argc = 0;
	}
	while(utmp.ut_name[0] == '\0') {
		namep = utmp.ut_name;
		printf("login: ");
		while((c = getchar()) != '\n') {
			if(c == ' ')
				c = '_';
			if(c == EOF)
				exit(0);
			if(namep < utmp.ut_name + 8)
				*namep++ = c;
		}
	}
	setpwent();
	if((pwd = getpwnam(utmp.ut_name)) == NULL)
		pwd = &nouser;
	endpwent();
	if(*pwd->pw_passwd != '\0') {
		namep = crypt(getpass("Password:"), pwd->pw_passwd);
		if(strcmp(namep, pwd->pw_passwd)) {
			printf("Login incorrect\n");
			goto loop;
		}
	}
	if(chdir(pwd->pw_dir) < 0) {
		printf("No directory\n");
		goto loop;
	}
	(void)time(&utmp.ut_time);
	t = ttyslot();
	if(t > 0 && (f = open("/etc/utmp", 1)) >= 0) {
		(void)lseek(f, (long)(t * sizeof(utmp)), 0);
		SCPYN(utmp.ut_line, index(ttyn + 1, '/') + 1);
		(void)write(f, (char *)&utmp, sizeof(utmp));
		(void)close(f);
	}
	if(t > 0 && (f = open("/usr/adm/wtmp", 1)) >= 0) {
		(void)lseek(f, 0L, 2);
		(void)write(f, (char *)&utmp, sizeof(utmp));
		(void)close(f);
	}
	(void)chown(ttyn, pwd->pw_uid, pwd->pw_gid);
	(void)setgid(pwd->pw_gid);
	(void)setuid(pwd->pw_uid);
	if(*pwd->pw_shell == '\0')
		pwd->pw_shell = "/bin/sh";
	environ = envinit;
	(void)strncat(homedir, pwd->pw_dir, sizeof(homedir) - 6);
	if((namep = rindex(pwd->pw_shell, '/')) == NULL)
		namep = pwd->pw_shell;
	else
		namep++;
	(void)strcat(minusnam, namep);
	(void)alarm(0);
	(void)umask(02);
	showmotd();
	(void)strcat(maildir, pwd->pw_name);
	if(access(maildir, 4) == 0) {
		struct stat statb;
		(void)stat(maildir, &statb);
		if(statb.st_size)
			printf("You have mail.\n");
	}
	(void)signal(SIGQUIT, (int)SIG_DFL);
	(void)signal(SIGINT, (int)SIG_DFL);
	(void)execlp(pwd->pw_shell, minusnam, 0);
	printf("No shell\n");
	exit(0);
	return(1);
}

static void
catch(int sig)
{
	(void)sig;
	(void)signal(SIGINT, (int)SIG_IGN);
	stopmotd++;
}

static void
showmotd(void)
{
	FILE *mf;
	int c;

	(void)signal(SIGINT, (int)catch);
	if((mf = fopen("/etc/motd", "r")) != NULL) {
		while((c = getc(mf)) != EOF && stopmotd == 0)
			putchar(c);
		(void)fclose(mf);
	}
	(void)signal(SIGINT, (int)SIG_IGN);
}
