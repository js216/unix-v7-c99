#include <a.out.h>

int	open(char *, int);
int	close(int);
int	read(int, char *, int);
long	lseek(int, long, int);
#define	ELF_NIDENT	16
#define	ELFMAG0		0177
#define	SHT_SYMTAB	2
#define	SHT_NOBITS	8
#define	SHF_EXECINSTR	4
#define	SHN_ABS		0xfff1
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
int
nlist(char *name, struct nlist *list)
{
	struct nlist *p;
	struct elfhdr eh;
	struct elfshdr sh;
	struct elfsym syms[64], *sym;
	char strbuf[10];
	char nb[9];
	char *sn;
	int f, i, j, k, n, nsyms;
	int matched;
	unsigned int symoff, symsz;
	unsigned int stroff;
	int sectype[64];

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
	stroff = 0;

	for(i = 0; i < eh.e_shnum && i < 64; i++) {
		lseek(f, (long)(eh.e_shoff + i * eh.e_shentsize), 0);
		if(readn(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
			close(f);
			return(-1);
		}
		if(sh.sh_flags & SHF_EXECINSTR)
			sectype[i] = N_TEXT;
		else if(sh.sh_type == SHT_NOBITS)
			sectype[i] = N_BSS;
		else
			sectype[i] = N_DATA;
		if(sh.sh_type == SHT_SYMTAB) {
			symoff = sh.sh_offset;
			symsz = sh.sh_size;
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
	nsyms = (int)(symsz / sizeof(syms[0]));
	for(i = 0; i < nsyms; i++) {
		if(i % 64 == 0) {
			n = nsyms - i < 64 ? nsyms - i : 64;
			n *= sizeof(syms[0]);
			lseek(f, (long)(symoff + i * sizeof(syms[0])), 0);
			if(readn(f, (char *)syms, n) != n) {
				close(f);
				return(-1);
			}
		}
		sym = &syms[i % 64];
		if(sym->st_name == 0)
			continue;
		lseek(f, (long)(stroff + sym->st_name), 0);
		k = readn(f, strbuf, 9);
		if(k <= 0) {
			close(f);
			return(-1);
		}
		strbuf[k] = '\0';
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
			p->n_value = sym->st_value;
			if(sym->st_shndx == SHN_ABS)
				p->n_type = N_ABS;
			else if(sym->st_shndx == 0 || sym->st_shndx >= 64)
				p->n_type = N_UNDF;
			else
				p->n_type = sectype[sym->st_shndx];
			if(sym->st_info >> 4)
				p->n_type |= N_EXT;
		}
	}
	close(f);
	return(0);
}
