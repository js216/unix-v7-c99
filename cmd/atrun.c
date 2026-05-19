/*
 * Run programs submitted by at.
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/dir.h>
#include <time.h>
#include <sys/stat.h>

# define DIR "/usr/spool/at"
# define PDIR	"past"
# define LASTF "/usr/spool/at/lasttimedone"

int	makenowtime(), updatetime(), run(), movefile();

int	nowtime;
int	nowdate;
int	nowyear;

int
main(argc, argv)
int argc;
char **argv;
{
	int tt, day, year, uniq;
	struct direct dirent;
	char file[DIRSIZ+1];
	FILE *dirf;
	(void)argc; (void)argv;

	chdir(DIR);
	makenowtime();
	if ((dirf = fopen(".", "r")) == NULL) {
		fprintf(stderr, "Cannot read at directory\n");
		exit(1);
	}
	while (fread((char *)&dirent, sizeof(dirent), 1, dirf) == 1) {
		if (dirent.d_ino==0)
			continue;
		strncpy(file, dirent.d_name, DIRSIZ);
		file[DIRSIZ] = '\0';
		if (sscanf(file, "%2d.%3d.%4d.%2d", &year, &day, &tt, &uniq) != 4)
			continue;
		if (nowyear < year)
			continue;
		if (nowyear==year && nowdate < day)
			continue;
		if (nowyear==year && nowdate==day && nowtime < tt)
			continue;
		run(file);
	}
	fclose(dirf);
	updatetime(nowtime);
	exit(0);
}

int
makenowtime()
{
	long t;
	register struct tm *tp;

	time(&t);
	tp = localtime(&t);
	nowtime = tp->tm_hour*100 + tp->tm_min;
	nowdate = tp->tm_yday;
	nowyear = tp->tm_year;
	return(0);
}

int
updatetime(t)
int t;
{
	FILE *tfile;

	tfile = fopen(LASTF, "w");
	if (tfile == NULL) {
		fprintf(stderr, "can't write lastfile\n");
		exit(1);
	}
	fprintf(tfile, "%04d\n", t);
	return(0);
}

int
run(file)
char *file;
{
	struct stat stbuf;
	register int pid, i;

	if (fork()!=0)
		return(0);
	for (i=0; i<15; i++)
		close(i);
	dup(dup(open("/dev/null", 0)));
	if (movefile(file, PDIR) < 0)
		exit(1);
	chdir(PDIR);
	if (stat(file, &stbuf) == -1)
		exit(1);
	setgid(stbuf.st_gid);
	setuid(stbuf.st_uid);
	if (pid = fork()) {
		if (pid == -1)
			exit(1);
	wait((int *)0);
	unlink(file);
		exit(0);
	}
	nice(3);
	close(0);
	open(file, 0);
	execl("/bin/sh", "sh", 0);
	execl("/usr/bin/sh", "sh", 0);
	fprintf(stderr, "Can't execl shell\n");
	exit(1);
	return(0);
}

int
movefile(file, dir)
char *file, *dir;
{
	int pid, status;

	pid = fork();
	if (pid == 0) {
		execl("/bin/mv", "mv", file, dir, 0);
		execl("/usr/bin/mv", "mv", file, dir, 0);
		exit(1);
	}
	if (pid == -1)
		return(-1);
	while (wait(&status) != pid)
		;
	if (status)
		return(-1);
	return(0);
}
