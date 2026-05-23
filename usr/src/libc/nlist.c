/* ARM/ELF nlist(3) -- v7's nlist parsed v7 a.out, but the C99/ARM
 * kernel is an ELF32 image, so this walks ELF .symtab/.strtab.  The
 * v7 C compiler prefixed every C symbol with `_'; strip one leading
 * underscore from each search-list name before matching against the
 * ELF symbol-string.  n_name[] is a fixed 8-byte field; we compare
 * against the ELF name with exact-match semantics, which is enough
 * for the kernel symbols that dmesg/ps look up (_msgbuf, _msgbufp,
 * _proc, _file, _swapdev, _dk_xfer, etc., all <=7 chars).  n_type is
 * mapped to v7's N_TEXT/N_DATA/N_BSS based on the ELF section's
 * SHF_EXECINSTR/SHF_WRITE flags.
 */
#include <a.out.h>

int	open(char *, int);
int	close(int);
int	read(int, char *, int);
long	lseek(int, long, int);
#define	ELF_NIDENT	16
#define	ELFMAG0		0177
#define	SHT_SYMTAB	2
#define	SHT_STRTAB	3
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
int
nlist(char *name, struct nlist *list)
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
	if(read(f, (char *)&eh, sizeof(eh)) != sizeof(eh)
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
		if(read(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
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
			read(f, (char *)&sh, sizeof(sh));
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
		if(read(f, (char *)&sym, sizeof(sym)) != sizeof(sym))
			break;
		if(sym.st_name == 0)
			continue;
		lseek(f, (long)(stroff + sym.st_name), 0);
		k = read(f, strbuf, sizeof(strbuf) - 1);
		if(k <= 0)
			continue;
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
