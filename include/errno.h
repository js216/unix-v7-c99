#define	ESPIPE	29
int	read(int, char *, int);
int	write(int, char *, int);
int	open(char *, int);
int	close(int);
long	lseek(int, long, int);
int	fstat(int, struct stat *);
int	strlen(char *);
void	exit(int);
