#include <a.out.h>

int	open(char *, int);
int	close(int);
int	read(int, char *, int);
long	lseek(int, long, int);
#define	ELF_NIDENT	16
#define	ELFMAG0		0177
#define	SHT_SYMTAB	2
#define	SHF_WRITE	1
#define	SHF_EXECINSTR	4
struct elfhdr {
	unsigned char	e_ident[ELF_NIDENT];
	unsigned short	e_type;
	unsigned short	e_machine;
	unsigned int	e_version;
	unsigned int	e_entry;
	unsigned int	e_phoff;
	unsigned int	e_shoff;
	unsigned int	e_flags;
	unsigned short	e_ehsize;
	unsigned short	e_phentsize;
	unsigned short	e_phnum;
	unsigned short	e_shentsize;
	unsigned short	e_shnum;
	unsigned short	e_shstrndx;
};
struct elfshdr {
	unsigned int	sh_name;
	unsigned int	sh_type;
	unsigned int	sh_flags;
	unsigned int	sh_addr;
	unsigned int	sh_offset;
	unsigned int	sh_size;
	unsigned int	sh_link;
	unsigned int	sh_info;
	unsigned int	sh_addralign;
	unsigned int	sh_entsize;
};
struct elfsym {
	unsigned int	st_name;
	unsigned int	st_value;
	unsigned int	st_size;
	unsigned char	st_info;
	unsigned char	st_other;
	unsigned short	st_shndx;
};
static int
readn(int fd, char *buf, int n)
{
	int nr, total;
	total = 0;
	while(total < n) {
		nr = read(fd, buf + total, n - total);
		if(nr <= 0)
			return(total);
		total += nr;
	}
	return(total);
}
static int
readstr(int fd, char *buf, int n)
{
	int nr, total;
	char c;
	total = 0;
	while(total < n - 1) {
		nr = read(fd, &c, 1);
		if(nr <= 0)
			break;
		buf[total++] = c;
		if(c == '\0')
			return(total);
	}
	buf[total] = '\0';
	return(total);
}
static int
nlist1(char *name, struct nlist *list)
{
	struct nlist *p;
	struct elfhdr eh;
	struct elfshdr sh;
	struct elfsym sym;
	char strbuf[64];
	char nb[9];
	char *sn;
	int f, i, j, k, nsyms;
	int matched;
	unsigned int symoff, symsz, symesz;
	unsigned int stroff;
	unsigned int secflags[64];

	for(p = list; p->n_name[0]; p++) {
		p->n_type = 0;
		p->n_value = 0;
	}
	f = open(name, 0);
	if(f < 0)
		return(-1);
	if(readn(f, (char *)&eh, sizeof(eh)) != sizeof(eh)
	    || eh.e_ident[0] != ELFMAG0 || eh.e_ident[1] != 'E'
	    || eh.e_ident[2] != 'L' || eh.e_ident[3] != 'F') {
		close(f);
		return(-1);
	}
	symoff = 0;
	symsz = 0;
	symesz = sizeof(sym);
	stroff = 0;

	for(i = 0; i < eh.e_shnum && i < 64; i++) {
		lseek(f, (long)(eh.e_shoff + i * eh.e_shentsize), 0);
		if(readn(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
			close(f);
			return(-1);
		}
		secflags[i] = sh.sh_flags;
		if(sh.sh_type == SHT_SYMTAB) {
			symoff = sh.sh_offset;
			symsz = sh.sh_size;
			if(sh.sh_entsize)
				symesz = sh.sh_entsize;
			lseek(f, (long)(eh.e_shoff + sh.sh_link * eh.e_shentsize), 0);
			if(readn(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
				close(f);
				return(-1);
			}
			stroff = sh.sh_offset;
		}
	}
	if(symoff == 0 || stroff == 0) {
		close(f);
		return(-1);
	}
	nsyms = (int)(symsz / symesz);
	for(i = 0; i < nsyms; i++) {
		lseek(f, (long)(symoff + i * symesz), 0);
		if(readn(f, (char *)&sym, sizeof(sym)) != sizeof(sym)) {
			close(f);
			return(-1);
		}
		if(sym.st_name == 0)
			continue;
		lseek(f, (long)(stroff + sym.st_name), 0);
		k = readstr(f, strbuf, sizeof(strbuf));
		if(k <= 0) {
			close(f);
			return(-1);
		}
		for(p = list; p->n_name[0]; p++) {
			for(j = 0; j < 8; j++)
				nb[j] = p->n_name[j];
			nb[8] = '\0';
			sn = nb;
			if(*sn == '_')
				sn++;
			matched = 1;
			for(j = 0; sn[j]; j++)
				if(sn[j] != strbuf[j]) {
					matched = 0;
					break;
				}
			if(!matched || strbuf[j] != '\0')
				continue;
			p->n_value = sym.st_value;
			if(sym.st_shndx == 0 || sym.st_shndx >= 64)
				p->n_type = N_UNDF;
			else if(secflags[sym.st_shndx] & SHF_EXECINSTR)
				p->n_type = N_TEXT | N_EXT;
			else if(secflags[sym.st_shndx] & SHF_WRITE)
				p->n_type = N_DATA | N_EXT;
			else
				p->n_type = N_BSS | N_EXT;
		}
	}
	close(f);
	return(0);
}
int
nlist(char *name, struct nlist *list)
{
	struct nlist *p;
	int tries, rc, matched;
	for(tries = 0; tries < 3; tries++) {
		rc = nlist1(name, list);
		matched = 0;
		for(p = list; p->n_name[0]; p++)
			if(p->n_type != 0)
				matched = 1;
		if(rc == 0 && matched)
			return(0);
	}
	return(rc);
}
