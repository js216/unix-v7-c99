# UNIX v7 → c99 Historical Accuracy Log

Tracks per-file deltas between the v7 originals under `v7/usr/src/cmd/`
and the buildable copies under `cmd/`.  Each entry summarises what
the minimal K&R → c99 conversion touched and, where the port had to
be skipped, why.

## Inventory

| v7 file | port status | landing path | notes |
|---------|-------------|--------------|-------|
| cmd/awk/* | ported | root/bin/awk | static yacc outputs plus small C lexer; K&R->C99 fixes; parser accepts bare expression patterns for `awk 1`; argv shim joins `{...}`, `BEGIN {...}`, `END {...}`, and action+`END` programs split by this shell |
| cmd/prof.c | ported | root/bin/prof | minimal K&R fixes + ftime rename + `unsigned UNIT` cleanup |
| cmd/tc.c   | ported | root/bin/tc   | minimal K&R fixes + tc-local `atoi` rename + signal casts |
| cmd/ps.c   | ported | root/bin/ps   | minimal K&R fixes + include-path rewrites (h/ vs sys/) + drop /dev/swap fatal-exit + skip user-image scan when p_size==0 |
| cmd/pstat.c| ported | root/bin/pstat| minimal K&R fixes + include-path rewrites (h/ vs sys/) + hoist in-function `#include`s to file scope + brace each setup[] initialiser + `#define GRP_H` to gate libc grp.h |
| cmd/sa.c   | ported | root/bin/sa   | minimal K&R fixes + inline `struct acct` (no userland `<sys/acct.h>` in this port) matched to arch/v7stubs.c's wire layout + `getpw()` -> `getpwuid()` swap + an `acct(NULL) / acct(path)` toggle in main() to iput()-flush the dinode that acctp keeps pinned |
| cmd/osh.c  | ported | root/bin/osh | mechanical rewrite of pre-K&R compound assignments (`=+`/`=-`/`=\|` -> `+=`/`-=`/`\|=`); single missing `=` in `char *mesg[NSIG] {` initialiser fixed; built with SHCFLAGS like the v7 Bourne sh |
| cmd/units.c | ported | root/bin/units + root/usr/lib/units | minimal K&R-to-C99 declarations/returns/signals; V7 units table copied from `v7/usr/lib/units` into `/usr/lib/units`; table-load banner uses `%d` because this libc does not implement V7's bare `%l` printf form |
| cmd/graph.c | ported | root/bin/graph | minimal K&R-to-C99 declarations/returns already present; local plot(5) emitter copied from v7 libplot's portable backend; narrow local `fabs`/`floor`/`ceil`/`log10` helpers because ARM libc has no libm; accepts one trailing input file operand for smoke tests while preserving stdin input |
| cmd/spline.c | ported | root/bin/spline | minimal K&R-to-C99 declarations/returns only; spline algorithm, options, interpolation output, and embedded historical notes match the V7 source |
| v7/bin/plot | installed | root/bin/plot | original V7 shell dispatcher copied verbatim into root staging; this slice supports `-Ttek`, `-T4014`, and `-T` through the installed `tek` backend |
| cmd/tek.c | ported | root/bin/tek | C99 userspace Tektronix 4014 backend combining V7 `cmd/plot/driver.c` plot(5) input dispatch with V7 `libplot/t4014.c.a` drawing behavior; other terminal backends intentionally not wired |
| v7/bin/nohup | installed | root/bin/nohup | original V7 shell script copied verbatim into root staging and installed as `/bin/nohup` |
| v7/bin/1 | installed | root/bin/1 | original V7 shell script copied verbatim into root staging and installed as `/bin/1` |
| cmd/fgrep.c | ported | root/bin/fgrep | V7 fixed-string grep retained; only narrow C99 declarations/prototypes and explicit `int` locals added |
| cmd/egrep.y | ported | root/bin/egrep | checked-in C99 translation with hand recursive parser replacing yacc; V7 DFA construction, executor, and option behavior retained |
| cmd/expr.y | ported | root/bin/expr | hand C99 recursive-descent parser; V7 argv-token lexer and ed-style regex matcher translated locally, no yacc/lex build dependency |
| cmd/ed.c | ported | root/bin/ed | V7 line editor retained; only local `<stdio.h>` inclusion with a guarded `puts` macro rename differs from the historical source |
| cmd/file.c | ported | root/bin/file | V7 file-type recognizer retained; only C99 declarations/prototypes, local device-number helpers, and disabled-comment terminator repair added |
| cmd/find.c | ported | root/bin/find | V7 traversal, predicate parser, predicates, `-exec`, and cpio writer retained; only C99 declarations/returns plus two ARM-runtime guards for cwd discovery and absent `/etc/group` numeric fallback |
| cmd/sort.c | ported | root/bin/sort | V7 sort/merge/key comparison retained; only C99 declarations/returns, signal casts, local qsort symbol rename, and ARM heap sizing from current break |
| cmd/tsort.c | ported | root/bin/tsort | V7 topological-sort graph algorithm retained; only C99 declarations/returns, local `index` rename, and fixed two historical one-argument internal error calls |
| dev/dsort.c | ported | kernel object | byte-identical to `v7/usr/sys/dev/dsort.c`; generalized disk seek-sort queue retained |
| lib/qsort.c | ported | libc.a | V7 libc quicksort retained; only C99 prototypes/returns, `void *` public argument, explicit `int` locals, and unsigned size comparison |
| cmd/iostat.c | ported | root/bin/iostat | existing C99-ready copy now wired into the normal BIN build/install path |
| cmd/dc/* | ported | root/bin/dc | existing V7 dc C99 carry-over kept behaviorally intact; root image now depends on `cmd/dc/*`, installs `/bin/dc`, and `lib/Makefile clean` removes staged `root/bin/dc` |
| cmd/tar/tar.c | ported | root/bin/tar | V7 tar source retained with only C99 declarations/returns and pointer casts needed by the strict ARM build; root image now depends on `cmd/tar/*`, installs `/bin/tar`, and `lib/Makefile clean` removes staged `root/bin/tar` |
| cmd/login.c | ported | root/bin/login | V7 login source already wired into the normal ARM build; this slice keeps the authentication/session flow historical and verifies it through getty/login/sh |
| lib/getlogin.c | ported | libc.a | V7 utmp lookup retained, with only the out-of-bounds 8-byte-name terminator moved into a private 9-byte return buffer |
| cmd/passwd.c | ported | root/bin/passwd | V7 password update flow retained; only C99 declaration/prototype cleanup and signal handler casts differ; installed as `/bin/passwd` and verified in QEMU against `/etc/passwd` |
| cmd/random.c | ported | root/bin/random | V7 random line filter retained; only K&R `main` was converted to an explicit C99 `int main(int argc, char **argv)` signature; installed as `/bin/random` and verified in QEMU |
| cmd/echo.c | ported | root/bin/echo | V7 echo retained exactly, including the simple `argv[1][0] == '-' && argv[1][1] == 'n'` newline suppression quirk; only K&R `main` was converted to C99 `int main(int argc, char *argv[])` |
| cmd/ln.c | ported | root/bin/ln | V7 link command retained; only K&R `main` was converted to C99 `int main(int argc, char **argv)` |
| cmd/umount.c | ported | root/bin/umount | V7 unmount command retained; only `<stdio.h>` and C99 `int main(int argc, char **argv)` differ; syscall 22 now routes through V7 `sumount()` |
| cmd/kill.c | ported | root/bin/kill | V7 kill retained; only C99/Armv7 prototypes, explicit return type, `argc` declaration, and typed register locals differ |
| cmd/ncheck.c | ported | root/bin/ncheck | V7 filesystem name checker retained; only C99 prototypes, explicit return types/returns, typed locals, and unsigned-bound casts differ |
| cmd/cb.c | ported | root/bin/cb | V7 C beautifier retained; only C99 prototypes, explicit return types/returns, unused-argument suppression, and local puts/gets renames differ |
| cmd/sp.c | ported | root/bin/sp | V7 horizontal line compactor retained; only C99 prototypes, explicit return types/returns, and typed locals differ |
| cmd/split.c | ported | root/bin/split | V7 file splitter retained; only C99 prototypes, explicit `int` return/locals, argc declaration, and unsigned loop-bound cast differ |
| cmd/learn/* | ported slice | root/bin/learn, root/usr/lib/learn/{tee,lcount}, root/usr/lib/learn/{files,morefiles}/* | bounded V7 learn(1) slices only: executable plus `tee`/`lcount` helpers, the `files` course extracted from V7 old-ar `files.a`, and the `morefiles` course extracted from V7 old-ar `morefiles.a`; broader courses and surrounding material intentionally omitted |
| cmd/chess/* | object-build slice | not installed | V7 `usr/src/games/chess` C sources plus chess-local `qsort.s`, `wmove.s`, `bmove.s`, `wgen.s`, `bgen.s`, `att.s`, and `ctrl.s` helpers translated to ARM C99 objects only; full executable wiring and root-image installation intentionally omitted |

## Ported file diffs

### chess(6) helper object-build slice

Original sources are from `v7/usr/src/games/chess/`: `agen.c`,
`bheur.c`, `book.c`, `bplay.c`, `data.c`, `init.c`, `io.c`,
`mater.c`, `old.h`, `play.c`, `pio.c`, `savres.c`, `setup.c`, `stat.c`,
`stdin.c`, `wheur.c`, and `wplay.c`, plus the local helper translated
from `qsort.s`, the move/undo helpers translated from `wmove.s` and
`bmove.s`, the pseudo-legal generators translated from `wgen.s` and
`bgen.s`, and the attack/control helpers translated from `att.s` and
`ctrl.s`.  They land under `cmd/chess/`.

This is deliberately an object-build slice only.  The V7 assembly move
generators are translated locally, but `/usr/games/chess` is not wired
into the root image and should not be treated as installed.

The local `cmd/chess/Makefile` builds just the pure-C objects with the
same ARM freestanding model used by the userland build:

```
make -C cmd/chess clean objects
```

Source comparison against V7 is limited to syntax/ABI preservation for
C99 object compilation:

* old-style global initializers in `data.c` were rewritten to C
  initializer syntax, and the heuristic dispatch tables are now typed as
  arrays of function pointers instead of integer arrays holding code
  addresses;
* outside `pio.c`, pre-K&R compound assignment spellings (`=+`, `=-`,
  `=|`, `=/`, `=>>`) were mechanically rewritten to their C
  equivalents; in `pio.c`, only the two C99-syntax-blocking `=%`
  spellings in `putnumb()` were changed to `%=` after direct import;
* `book.c`'s PDP-11 anonymous byte-field overlay in `booki()` was
  replaced with an explicit low-16-bit byte swap expression;
* `qsort.s` is translated locally as `cmd/chess/qsort.c`: move-list
  records are still two-int `(key, move)` pairs in the half-open range
  `[from, to)`, sorted ascending by key; the public sorter is named
  `chess_qsort` and old chess callers are redirected in `old.h` to avoid
  a libc `qsort` collision;
* `wmove.s` and `bmove.s` are translated locally as `cmd/chess/wmove.c`
  and `cmd/chess/bmove.c`: move encoding remains `(from << 8) | to`
  with PDP-11 low/high byte extraction, the undo stack remains exactly
  `old value, old flag, old eppos, from, to, captured piece, move type`,
  and the assembly's king, rook, en-passant, promotion, castling,
  value, flag, `eppos`, and king-position state changes are retained;
* `wgen.s` and `bgen.s` are translated locally as `cmd/chess/wgen.c`
  and `cmd/chess/bgen.c`: pseudo-legal generation scans squares 63 down
  to 0, retains piece direction order, appends two-int
  `(score, (from << 8) | to)` records to `lmp`, keeps the historical
  score formulas and pawn/en-passant encodings, and leaves castling plus
  self-check filtering to `agen.c`;
* `att.s` is translated locally as `cmd/chess/att.c`: `battack()` and
  `wattack()` retain the historical return convention of `0` for
  attacked and `1` for not attacked, black-positive/white-negative piece
  values, PDP-11 byte offsets divided by two, adjacent-king attacks, and
  first-blocker ray behavior;
* `ctrl.s` is translated locally as `cmd/chess/ctrl.c`: `attack()` fills
  `attacv[]` in assembly order and terminates with zero, while retaining
  the historical omissions of the `d1r2` knight offset and king entries
  plus the original sliding scan that continues through recognized
  sliders;
* `cmd/chess/move_check.c` is a host-only targeted harness, run by
  `make -C cmd/chess check-move`, covering ordinary moves,
  captures/value restoration, castling and undo, en-passant and undo,
  double-pawn `eppos`, promotion and undo, rook castling-flag clearing,
  king-position restoration, queen opening value tweaks, and undo-record
  pointer advancement/restoration for both colors;
* `cmd/chess/attack_check.c` is a host-only targeted harness, run by
  `make -C cmd/chess check-attack`, covering no-attack cases, pawns,
  all attack-detector knight directions and edge masks, rook/bishop/queen
  rays, blocking, adjacent versus distant kings, `attacv[]` ordering and
  termination, pawns/knights/sliders in `attack()`, the omitted `d1r2`
  control offset, omitted king entries, and the historical slider-scan
  behavior;
* `cmd/chess/gen_check.c` is a host-only targeted harness, run by
  `make -C cmd/chess check-gen`, covering initial pseudo-legal counts,
  scan and direction order, knight edge masks, slider empty/capture/stop
  behavior, pawn singles/doubles/captures, historical en-passant encoded
  adjacent-pawn moves, score formulas, and `lmp` append advancement;
* `cmd/chess/qsort.c` also provides the historical chess-local `itinit()`,
  `onhup()`, interrupt re-arm/increment behavior for `intrp`, and
  elapsed-second `clock()` state using this port's V7-style `signal`
  and `time` calls;
* no full chess executable link, root-image installation, gameplay
  policy change, or castling move generation was added in this slice.

### learn(1) files-course slice

Original sources are from `v7/usr/src/cmd/learn/`: `copy.c`,
`dounit.c`, `learn.c`, `list.c`, `makpipe.c`, `maktee.c`, `mem.c`,
`mysys.c`, `selsub.c`, `selunit.c`, `start.c`, `whatnow.c`,
`wrapup.c`, `lcount.c`, `tee.c`, plus `lrndef` and `lrnref`.
They land under `cmd/learn/` and build as `/bin/learn`,
`/usr/lib/learn/lcount`, and `/usr/lib/learn/tee`.

Course data provenance:

* `root/usr/lib/learn/Linfo` and `root/usr/lib/learn/Xinfo` are copied
  from `v7/usr/lib/learn/`.
* `root/usr/lib/learn/files/*` contains the 75 members of
  `v7/usr/lib/learn/files.a`, extracted by `tools/extract-old-ar.py`
  from the old V7 16-bit archive format described by
  `v7/usr/include/ar.h`.
* `root/usr/lib/learn/morefiles/*` contains the 45 members of
  `v7/usr/lib/learn/morefiles.a`, extracted by the same
  `tools/extract-old-ar.py` path.  The staged payload is 72,093 bytes
  from the 73,294-byte archive.
* `root/usr/lib/learn/play` and `root/usr/lib/learn/log` are writable
  root-image directories used by the historical program.

Source comparison against V7 is intentionally small:

```diff
--- v7/usr/src/cmd/learn/mysys.c
+++ cmd/learn/mysys.c
@@
-		nv = getargs(p, np);
+		nv = lrn_getargs(p, np);
@@
-getargs(s, v)
+lrn_getargs(s, v)
 char *s, **v;
```

The rename avoids a C99 prototype collision with this port's libc
`getargs(char **, int)` declaration; the local parser body is otherwise
the V7 code.

```diff
--- v7/usr/src/cmd/learn/selsub.c
+++ cmd/learn/selsub.c
@@
-		fprintf(stderr, "can't cd to %s\\,", direct);
+		fprintf(stderr, "can't cd to %s,", direct);
```

This removes an invalid C escape accepted by older compilers.

```diff
--- v7/usr/src/cmd/learn/start.c
+++ cmd/learn/start.c
@@
-	struct direct {
-		int inode; 
-		char name[14];
-	};
 	struct direct dv[ND], *dm, *dp;
@@
-		if (dp->inode) {
-			n = strlen(dp->name);
-			if (dp->name[n-2] == '.' && dp->name[n-1] == 'c')
+		if (dp->d_ino) {
+			n = strlen(dp->d_name);
+			if (n >= 2 && dp->d_name[n-2] == '.' && dp->d_name[n-1] == 'c')
 				continue;
-			c = dp->name[0];
+			c = dp->d_name[0];
 			if (c>='a' && c<= 'z')
-				unlink(dp->name);
+				unlink(dp->d_name);
 		}
```

The local PDP-11 directory struct used a 32-bit `int inode` on Armv7,
which does not match this port's 16-byte `struct direct` with
`ino_t d_ino`; using the existing V7 userland header keeps directory
cleanup aligned with the target filesystem layout.  The `n >= 2` guard
prevents the old suffix test from indexing before `"."`.

Build/install wiring was added to `Makefile`, `lib/Makefile`, and
`conf/qemu_arm/root.proto` for only this bounded slice.

The `editor`, `macros`, `eqn`, `C`, full `games/chess` executable,
toolchain, troff/doc, network/mail/uucp, and standalone material were
not ported in this slice.

### echo.c

Original at `v7/usr/src/cmd/echo.c`.  The port lands as `cmd/echo.c`
and installs as `/bin/echo`.

Source comparison against the V7 file shows the argument printing loop
and historical `-n` check are unchanged.  There is no modern option
parser and no escape handling.  The only intended source delta is the
C99 `main` signature:

```diff
--- v7/usr/src/cmd/echo.c	1979-01-10 12:01:32.000000000 -0800
+++ cmd/echo.c	2026-05-10 07:15:58.906680187 -0700
@@ -1,8 +1,7 @@
 #include <stdio.h>
 
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])
 {
 	register int i, nflg;
```

Build/install wiring already included `echo` in the top-level
`Makefile` root set, in `lib/Makefile`'s `BIN` loop, and in
`conf/qemu_arm/root.proto` as `/bin/echo`.  No source or build wiring
change was required for this slice.

### ed.c

Original at `v7/usr/src/cmd/ed.c`.  The port lands as `cmd/ed.c` and
installs as `/bin/ed`.

Source comparison against the V7 file shows the editor implementation is
otherwise unchanged: command parsing, address handling, temporary-file
block storage, append/change/delete/move/copy behavior, substitution and
regular-expression engine, diagnostics, encryption hooks, and option
handling remain the historical source.  This slice made no source or
build-wiring edits.

The complete source delta is the local stdio include needed by this
userland, with `puts` guarded so the local libc declaration does not
collide with ed's historical `puts()` function later in the file:

```diff
--- v7/usr/src/cmd/ed.c	1979-01-10 12:01:34.000000000 -0800
+++ cmd/ed.c	2026-05-13 18:50:47.807310227 -0700
@@ -5,6 +5,9 @@
 #include <signal.h>
 #include <sgtty.h>
 #include <setjmp.h>
+#define	puts	u_puts
+#include <stdio.h>
+#undef	puts
 #define	NULL	0
 #define	FNSIZE	64
 #define	LBSIZE	512
```

Build/install inventory:

* top-level `Makefile`: `root/bin/ed` is a root-image prerequisite.
* `lib/Makefile`: builds `../cmd/ed.c` with `$(EDCFLAGS)`, links
  `ed.elf`, and installs `../root/bin/ed`.
* `conf/qemu_arm/root.proto`: installs `ed ---755 0 0 root/bin/ed`.

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`ed V7 line editor slice`.

### file.c

Original at `v7/usr/src/cmd/file.c`.  The port lands as
`cmd/file.c` and installs as `/bin/file`.

Source comparison against the V7 file shows the file-type recognizer is
unchanged: stat/open/read flow, magic numbers, C/Fortran/assembler/roff
heuristics, English/ascii/data classification, `-f` list handling, and
diagnostic text all match the historical source.  The complete source
delta is limited to C99 build requirements and one comment repair:

* Added file-scope prototypes for `type`, `lookup`, `ccom`, `ascom`,
  `english`, and libc `exit`.
* Gave `main`, `lookup`, `ccom`, `ascom`, and `english` explicit `int`
  return types; `type` is explicitly `void`.
* Added an explicit `int argc;` declaration to the K&R
  `main(argc, argv)` definition.
* Added the explicit `int n;` declaration for `english(bp, n)`.
* Added local `major()` / `minor()` macro definitions after undefining
  any header-provided names so special-file output keeps V7's
  `major/minor` formatting on this ARM userland.
* Corrected the disabled null-scan block terminator from V7's nested
  `/*.... */` spelling to plain `.... */`, so a C99 compiler parses the
  intentionally disabled block without changing runtime behavior.

Build/install wiring already included `file` in `lib/Makefile`'s `BIN`
loop and clean rule, the top-level `Makefile` root image prerequisites,
and `conf/qemu_arm/root.proto`, installing it as `/bin/file`.

Concrete source delta:

```diff
--- v7/usr/src/cmd/file.c
+++ cmd/file.c
@@
 int	ifile;
 
+void type(char *file);
+int lookup(char *tab[]);
+int ccom(void);
+int ascom(void);
+int english(char *bp, int n);
+void exit(int n);
+#undef major
+#undef minor
+#define major(x)	(((x)>>8)&0377)
+#define minor(x)	((x)&0377)
+int
 main(argc, argv)
+int argc;
 char **argv;
@@
+void
 type(file)
 char *file;
@@
-		/*.... */
+		.... */
 	printf("\n");
 out:;
 }
+int
 lookup(tab)
@@
+int
 ccom(){
@@
+int
 ascom(){
@@
+int
 english (bp, n)
 char *bp;
+int n;
```

### find.c

Original at `v7/usr/src/cmd/find.c`.  The port lands as `cmd/find.c`
and installs as `/bin/find`.

Source comparison against the V7 file shows the expression grammar and
runtime behavior are otherwise retained: path-list parsing,
`-o`/implicit-and/`!`/parentheses precedence, `-name`, time, owner,
inode, group, size, link-count, permission, type, `-exec`, `-ok`,
`-cpio`, `-newer`, recursive directory descent, glob matching, and the
historical binary cpio header writer are still the V7 code.

The source delta is limited to build correctness and two narrow runtime
guards exposed by the ARM root image:

* Added explicit C99 prototypes, return types, K&R parameter
  declarations, and explicit `int` locals for functions and old
  implicit-int variables.
* Defined `ctime` as `find_ctime` before including headers so the
  predicate helper does not collide with libc's `ctime`.
* Kept V7's start-directory discovery via `/bin/pwd`, but replaced
  `popen("pwd", "r")` with a local pipe/fork/exec helper.  This avoids
  this port's current `/bin/sh -c` diagnostic (`-c: is not an
  identifier`) while preserving the same observable cwd source for
  multi-path traversal and `-exec` reset-to-start-directory behavior.
* Changed `execvp(nargv[0], nargv, np)` to this libc's two-argument
  `execvp(nargv[0], nargv)` signature; the extra `np` was a V7 libc
  implementation detail.
* Made `getunum()` return `-1` when `/etc/passwd` or `/etc/group`
  cannot be opened.  V7 installations had those files; this root image
  lacks `/etc/group`, and returning "not found" lets the existing V7
  numeric fallback handle `-group 0` instead of dereferencing a null
  stream.

Build/install wiring was already present for this slice:
`lib/Makefile` includes `find` in the normal `BIN` loop and clean rule,
the top-level `Makefile` root image prerequisites include
`root/bin/find`, and `conf/qemu_arm/root.proto` installs it as
`/bin/find`.  No wiring edits were required.

Concrete source delta excerpt:

```diff
--- v7/usr/src/cmd/find.c
+++ cmd/find.c
@@
 #include <stdio.h>
+#define	ctime	find_ctime
 #include <sys/types.h>
@@
 char *rindex();
 char *sbrk();
+int	pr();
+int	gethome(void);
+int	descend(char *name, char *fname, struct anode *exlist);
+int	cpio(void);
+int	getunum(char *f, char *s);
+int	gmatch(char *s, char *p);
+int	scomp(int a, int b, int s);
+int	doex(int com);
+int	bwrite(short *rp, int c);
+int	chgreel(int x, int fl);
+int	amatch(char *s, char *p);
+int	umatch(char *s, char *p);
+int
 main(argc, argv) char *argv[];
+int argc;
 {
 	struct anode *exlist;
 	int paths;
 	register char *cp, *sp = 0;
-	FILE *pwd, *popen();
 
 	time(&Now);
-	pwd = popen("pwd", "r");
-	fgets(Home, 128, pwd);
-	pclose(pwd);
-	Home[strlen(Home) - 1] = '\0';
+	gethome();
@@
+int
+gethome()
+{
+	int fd[2], status;
+	register int n;
+
+	if(pipe(fd) < 0) {
+		pr("find: cannot run pwd\n");
+		exit(1);
+	}
+	if(fork() == 0) {
+		close(fd[0]);
+		dup(fd[1] | 0100, 1);
+		close(fd[1]);
+		execl("/bin/pwd", "pwd", 0);
+		exit(1);
+	}
+	close(fd[1]);
+	n = read(fd[0], Home, sizeof Home - 1);
+	close(fd[0]);
+	wait(&status);
+	if(n <= 0 || status) {
+		pr("find: cannot run pwd\n");
+		exit(1);
+	}
+	Home[n] = '\0';
+	if(Home[n - 1] == '\n')
+		Home[n - 1] = '\0';
+	return(0);
+}
@@
-		execvp(nargv[0], nargv, np);
+		execvp(nargv[0], nargv);
@@
 	i = -1;
 	pin = fopen(f, "r");
+	if(pin == NULL)
+		return(i);
 	c = '\n'; /* prime with a CR */
```

### fgrep.c

Original at `v7/usr/src/cmd/fgrep.c`.  The port lands as
`cmd/fgrep.c` and installs as `/bin/fgrep`.

Source comparison against the V7 file shows the fixed-string matcher,
keyword trie/failure-link construction, option parsing, diagnostics,
and exit-status logic are otherwise unchanged.  The complete source
delta is limited to C99 build requirements:

* Added file-scope prototypes for `execute`, `getargc`, `cgotofn`,
  `overflo`, `cfail`, and the libc `exit` entry used by this freestanding
  userland.
* Gave `main`, `getargc`, `execute`, `cgotofn`, `overflo`, and `cfail`
  explicit return types.  `execute`, `cgotofn`, `overflo`, and `cfail`
  are `void`; `main` and `getargc` are `int`.
* Added an explicit `int argc;` declaration to the K&R `main(argc, argv)`
  definition, matching the historical calling convention without moving
  to a prototype-style function definition.
* Changed K&R implicit local integers `register ccount;` and
  `register c;` to `register int ccount;` / `register int c;`.
* Build/install wiring names `fgrep` in `lib/Makefile`'s `BIN` loop and
  clean rule, the top-level root image prerequisites, and
  `conf/qemu_arm/root.proto`.

### egrep.y -> egrep.c

Original at `v7/usr/src/cmd/egrep.y`.  The port lands as
`cmd/egrep.c` and installs as `/bin/egrep`.

* Replaced the yacc grammar with a checked-in C99 recursive-descent
  parser for the same expression language: alternation, concatenation,
  grouping, `.`, bracket classes, negated bracket classes, `*`, `+`,
  `?`, and V7's `^`/`$` mapping to newline.
* Kept the V7 syntax-tree arrays (`name`, `left`, `right`, `parent`),
  follow-set construction (`cfoll`, `follow`, `cstate`), DFA table
  builder (`cgotofn`), and streaming executor layout close to the
  historical source.
* Preserved option semantics for `-s`, `-h`, `-b`, `-c`, `-e`, `-f`,
  `-l`, `-n`, and `-v`, including multi-file prefixes and exit statuses
  0 for matches, 1 for no matches, and 2 for syntax/open errors.
* C99-required changes are declarations/prototypes, explicit return
  types, initialized globals, and changing the historical `int fname`
  scratch variable to `char *fname` so `freopen` diagnostics print the
  pattern filename safely on Arm.
* Build/install wiring adds `egrep` to `lib/Makefile`'s `BIN` loop and
  clean rule, the top-level root image prerequisites, and
  `conf/qemu_arm/root.proto`.

### graph.c

Original at `v7/usr/src/cmd/graph.c`.  Conversion to c99 plus ARM
userland wiring:

* The pre-existing buildable copy already had explicit `int` returns,
  typed `register int` locals, and forward declarations for the K&R
  helper functions.
* Added local `fabs`, `floor`, `ceil`, and `log10` implementations in
  `cmd/graph.c`.  The ARM userland libc does not ship libm, and graph
  is currently the only remaining consumer of those floating helpers.
  `log10` is used only for graph's historical logarithmic axis option.
* Added local plot(5) routines (`space`, `erase`, `move`, `cont`,
  `line`, `point`, `label`, `linemod`, `closevt`, plus `putsi`) that
  match v7 `usr/src/libplot/plot.c.a` byte output.  The historical
  libplot archive is present under `v7/` but not ported or linked into
  this freestanding ARM libc.
* Added a trailing input-file operand fallback via `freopen(..., stdin)`.
  The v7 source itself reads stdin; this extension is scoped to graph
  and supports the qemu smoke command without changing the plot stream.
* Wired `graph` into `lib/Makefile`'s `/bin` build, the top-level
  rootfs dependency list, and `conf/qemu_arm/root.proto`.

### spline.c

Original at `v7/usr/src/cmd/spline.c`.  The checked-in
`cmd/spline.c` keeps the V7 cubic spline implementation and its
historical comment block intact.  The only source deltas are narrow
C99 build fixes:

* `rhs`, `spline`, `readin`, `getfloat`, `getlim`, `main`, and `numb`
  now have explicit `int` return types where the V7 source relied on
  implicit int.
* `rhs(i)` now declares `int i;` in K&R style, matching the existing
  file style while making the parameter type explicit for the C99
  compiler.
* `main(argc, argv)` now declares `int argc;`.
* `register c;` in `getfloat` is now `register int c;`.
* `readin` and `getlim` return `0` after their historical side effects
  so the explicit return type does not change runtime behavior.
* `int getfloat(), numb(), getlim();` was added before `readin` so the
  call sites keep the historical layout without relying on undeclared
  functions.
* Build/install wiring already includes `spline` in `lib/Makefile`'s
  `BIN`, the top-level `Makefile` root image prerequisites, and
  `conf/qemu_arm/root.proto`, installing it as `/bin/spline`.

Concrete source delta:

```
diff -u v7/usr/src/cmd/spline.c cmd/spline.c
@@
-rhs(i){
+rhs(i)
+int i;{
@@
+int
 spline(){
@@
+int	getfloat(), numb(), getlim();
+int
 readin() {
@@
-		if(!getfloat(&y.val[n])) break; } }
+		if(!getfloat(&y.val[n])) break; } return(0); }
@@
+int
 getfloat(p)
@@
-	register c;
+	register int c;
@@
+int
 getlim(p)
@@
-	}
+	return(0); }
@@
+int
 main(argc,argv)
+	int argc;
@@
+int
 numb(np,argcp,argvp)
```

### plot / tek

Original dispatcher at `v7/bin/plot`; original backend behavior from
`v7/usr/src/cmd/plot/driver.c` and `v7/usr/src/libplot/t4014.c.a`.
This slice deliberately ports only the Tektronix path:

* `lib/Makefile` now copies the V7 `/bin/plot` shell script verbatim
  into root staging and builds `cmd/tek.c` as `/bin/tek`.
* The top-level root image dependency list and `conf/qemu_arm/root.proto`
  include both `/bin/plot` and `/bin/tek`.
* `cmd/tek.c` is C99-portable target code for the V7 plot(5) driver
  commands (`m`, `l`, `t`, `e`, `p`, `n`, `s`, `a`, `c`, `f`, `d`) and
  the Tek 4014 output routines (`openpl`, `closepl`, `erase`, `label`,
  `linemod`, `line`, `move`, `cont`, `point`, `space`, `arc`, `circle`).
  The V7 t4014 `dot()` was an empty stub and remains a no-op here.
* The dispatcher still contains all historical cases, but this mission
  slice installs only `tek`; `-Ttek`, `-T4014`, and `-T` are the supported
  plot targets.

### prof.c

Original at `v7/usr/src/cmd/prof.c`.  Conversion to c99:

* Forward declarations for K&R int-returning helpers (`min`, `max`,
  `done`, `timcmp`, `valcmp`) so the compiler stops emitting
  implicit-declaration errors.
* `main`, `min`, `max`, `valcmp`, `timcmp`, `done` get explicit `int`
  return type and `main` gets `int argc` typed.
* `register j;` → `register int j;`.
* `unsigned UNIT ccnt;` (K&R "unsigned + typedef short") → plain
  `unsigned short ccnt;` — same wire format, accepted by c99.
* Global `ftime` collides with `int ftime(struct timeb *)` declared
  in our `<stdio.h>`; renamed to `ftim` throughout this TU.
* `if(lowpc == -1)` → `if(lowpc == (unsigned)-1)` (silences c99
  signed/unsigned compare error; semantically identical because lowpc
  is `unsigned` and -1 is converted to UINT_MAX on the LHS path).
* Variables `pfpos`, `lastsx`, `tx`, `ty` are only used inside the
  `#ifdef plot` block (libplot's vector backend, not available here);
  hoisted their decls under the same guard so the default build has no
  unused-but-set diagnostics.
* `done()` reached the closing brace without a `return`; added a
  trailing `return(0);` after the unreachable `exit(0)` to satisfy
  `-Werror=return-type`.

Diff hunks:

```diff
@@ -9,6 +9,11 @@
 typedef	short UNIT;		/* unit of profiling */
+int min(unsigned a, unsigned b);
+int max(unsigned a, unsigned b);
+int done(void);
+int timcmp(), valcmp();
+
@@ -39,7 +44,7 @@
-double	ftime;
+double	ftim;
@@ -53,16 +58,19 @@
-main(argc, argv)
+int main(argc, argv)
+int argc;
 char **argv;
 {
 	char *namfil;
 	int timcmp(), valcmp();
 	int i, overlap;
+#ifdef plot
 	long pfpos;
 	double lastsx;
-	struct cnt *cp;
 	double tx, ty;
+#endif
+	struct cnt *cp;
@@ -80,7 +88,7 @@
-				if(lowpc == -1)
+				if(lowpc == (unsigned)-1)
@@ -119,7 +127,9 @@
 	fread((char *)cbuf, sizeof(struct cnt), h.ncount, pfile);
+#ifdef plot
 	pfpos = ftell(pfile);
+#endif
@@ -150,8 +160,8 @@
 	for(i=0;;i++) {
-		register j;
-		unsigned UNIT ccnt;
+		register int j;
+		unsigned short ccnt;
@@ -159,17 +169,17 @@
-		ftime = ccnt;
-		totime += ftime;
-		if(ftime > maxtime)
-			maxtime = ftime;
+		ftim = ccnt;
+		totime += ftim;
+		if(ftim > maxtime)
+			maxtime = ftim;
@@ -261,7 +271,7 @@
-min(a, b)
+int min(a, b)
@@ -269,7 +279,7 @@
-max(a, b)
+int max(a, b)
@@ -277,13 +287,13 @@
-valcmp(p1, p2)
+int valcmp(p1, p2)
-timcmp(p1, p2)
+int timcmp(p1, p2)
@@ -296,7 +306,7 @@
-done()
+int done()
@@ -306,4 +316,5 @@
 	exit(0);
+	return(0);
 }
```

(plus the analogous `ftime → ftim` substitutions inside the unbuilt
`#ifdef plot` block, kept in tree for fidelity.)

### tc.c

Original at `v7/usr/src/cmd/tc.c`.  Conversion to c99:

* Forward declarations for K&R int-returning helpers (`lig`, `init`,
  `ex`, `kwait`, `callunix`, `readch`, `sendpt`, `tcatoi`, `getch`,
  `tscale`).
* `main`, `lig`, `init`, `ex`, `kwait`, `callunix`, `readch`,
  `sendpt`, `getch` get explicit `int` return type / `(void)`.
* `register i, j;` etc. → `register int i, j;`.
* The local `atoi()` is **not** the libc one — it reads from `*ap++`,
  with no string arg.  Renamed to `tcatoi()` here to avoid the
  conflicting-prototype error vs. libc `int atoi(char *s)`; all six
  call sites updated.
* `extern ex();` → `extern int ex();`.
* `signal(SIGINT, ex)` etc.: our `<stdio.h>` declares
  `int signal(int, int)`, so each call site is wrapped
  `signal(SIG, (int)func)` and assignment back into the
  `int(*)()` slot is `(int(*)())signal(...)`.  Matches the pattern
  used by `cmd/at.c`, `cmd/cron.c`, `cmd/diff.c`, etc.
* `return;` in void-typed K&R functions (`lig`, `init`, `ex`,
  `kwait`, `callunix`, `sendpt`) → `return(0);` (and the functions now
  return `int`).
* `char *asctab[128] {` → `char *asctab[128] = {` (K&R initialiser
  syntax not accepted by c99).
* `oput(c)` macro had a literal empty-else (`else;`) that c99
  flags `-Werror=empty-body`; rewrote as `else (void)0` so the
  control flow is unchanged and the macro stays a single statement
  for `if`-chains.

Diff hunks:

```diff
@@ -5,7 +5,7 @@
-#define	oput(c) if (pgskip==0) putchar(c); else;
+#define	oput(c) if (pgskip==0) putchar(c); else (void)0
@@ -54,20 +54,31 @@
-main(argc,argv)
+int lig(char *x);
+int init(void);
+int ex(void);
+int kwait(void);
+int callunix(char line[]);
+int readch(void);
+int sendpt(void);
+int tcatoi(void);
+int getch(void);
+long tscale(int n);
+
+int main(argc,argv)
 int argc;
 char **argv;
 {
-	register i, j;
+	register int i, j;
 	register char *k;
-	extern ex();
+	extern int ex();
@@ -75,7 +86,7 @@
-				if(i = atoi())pl = i/3;
+				if(i = tcatoi())pl = i/3;
@@ -91,8 +102,8 @@
-	sigint = signal(SIGINT, ex);
-	sigquit = signal(SIGQUIT, SIG_IGN);
+	sigint = (int(*)())signal(SIGINT, (int)ex);
+	sigquit = (int(*)())signal(SIGQUIT, (int)SIG_IGN);
@@ -223,10 +234,10 @@
-lig(x)
+int lig(x)
 char *x;
 {
-	register i, j;
+	register int i, j;
 	register char *k;
@@ -243,8 +254,9 @@
 	xx -= j;
 	sendpt();
+	return(0);
 }
-init(){
+int init(void){
@@ -259,8 +271,9 @@
 	skip = 0;
 	sendpt();
+	return(0);
 }
-ex(){
+int ex(void){
@@ -269,10 +282,11 @@
 	exit(0);
+	return(0);
 }
-kwait(){
+int kwait(void){
 	char buf[128]; char *bptr; char c;
-	if(pgskip) return;
+	if(pgskip) return(0);
@@ -295,31 +309,33 @@
-	else	return;
+	else	return(0);
+	return(0);
 }
-callunix(line)
+int callunix(line)
 char line[];
 {
 	int rc, status, unixpid;
 	if( (unixpid=fork())==0 ) {
-		signal(SIGINT,sigint); signal(SIGQUIT,sigquit);
+		signal(SIGINT,(int)sigint); signal(SIGQUIT,(int)sigquit);
@@ -340,14 +356,13 @@
-	return;
+	return(0);
 }
-atoi()
+int tcatoi(void)
 {
-	register i, j, acc;
+	register int i, j, acc;
 	int field, digits;
 	long dd;
-	long tscale();
@@ -411,7 +426,7 @@
-char *asctab[128] {
+char *asctab[128] = {
```

### ps.c

Original at `v7/usr/src/cmd/ps.c`.  Conversion to C99 plus the minimum
porting-layer adjustments:

* `<core.h>` was a tiny PDP-11-specific header (defines `TXTRNDSIZ`,
  `stacktop()`, `stackbas()`) that has no equivalent in this port;
  the three macros are inlined.
* `<sys/proc.h>`, `<sys/tty.h>`, `<sys/user.h>` do not exist under
  `include/sys/` in this port -- the kernel-internal headers live
  under `h/`.  Rerouted via `"../h/<x>.h"`.  `<sys/tty.h>` is dropped
  in favour of a `struct tty;` forward declaration because ps only
  uses `struct tty *` (through `u.u_ttyp`); pulling the full tty.h
  is unnecessary and would require `-fms-extensions` for the
  anonymous `struct tc;` union member.
* `char *strncmp();` -- a K&R-era stray forward declaration that
  clashes with `<stdio.h>`'s `int strncmp(char *, char *, int)` in
  this port; deleted.  Replaced by C99 prototypes for the local
  helpers (`getdev`, `prcom`, `getbyte`, `within`) so the file
  satisfies `-Wimplicit-function-declaration` against `-Werror`.
* `main`, `getdev`, `prcom`, `getbyte`, `within` get explicit
  `int` return type (and `int argc` / `int puid` typed parameters).
* `register i;` / `register i;` (in `gettty`, `getptr`) →
  `register int i;` / `register unsigned int i;`.
* `"0SWRIZT"[mproc.p_stat]` triggers `-Werror=char-subscripts`;
  cast through `(unsigned char)`.
* `getdev()` -- in v7 this aborts with "Can't open /dev/swap" when
  the device is missing; on the ARM port there is no /dev/swap, so
  the fatal exit is replaced with `swap = -1;` and prcom() guards
  the later swap reads with the negative fd (which just returns 0
  via the existing error path).
* `prcom()` -- adds an early `return(1)` when `mproc.p_size == 0`.
  The v7 algorithm computes
  `addr = ctob(p_addr) + ctob(p_size) - 512` for the user argv
  scan; this port's proc-table populator leaves p_addr/p_size both
  zero, so the original code drives `/dev/mem` reads to offset
  -512 (= 0xFFFFFE00 unsigned), which the kernel mem driver
  blindly turns into a `bcopy()` past the end of RAM and stalls
  the timer-driven console loop.  Skipping the scan lets ps finish
  the per-row print and move on; the proc-table fields it has
  already printed (pid, tty, time) are still accurate.

Diff hunks:

```diff
--- v7/usr/src/cmd/ps.c
+++ cmd/ps.c
@@ -5,12 +5,22 @@
 
 #include <stdio.h>
 #include <a.out.h>
-#include <core.h>
+/* core.h is not present in this port; inline the three macros it
+ * defines (v7 PDP-11 values).  Feeds the user-text/data/stack
+ * address-map setup in prcom(); only meaningful when the port can
+ * read a user struct out of swap, which is best-effort. */
+#define TXTRNDSIZ 8192L
+#define stacktop(siz) (0x10000L)
+#define stackbas(siz) (0x10000L-siz)
 #include <sys/param.h>
-#include <sys/proc.h>
-#include <sys/tty.h>
+/* v7 kernel-internal headers live under h/ in this port. */
+#include "../h/proc.h"
+/* sys/tty.h is not needed by this source (no struct tty fields are
+ * touched here); a forward declaration is enough for the struct tty *
+ * member referenced through u.u_ttyp. */
+struct tty;
 #include <sys/dir.h>
-#include <sys/user.h>
+#include "../h/user.h"
 
 struct nlist nl[] = {
 	{ "_proc" },
@@ -32,7 +42,12 @@
 long	lseek();
 char	*gettty();
 char	*getptr();
-char	*strncmp();
+/* strncmp() is declared in <stdio.h> with the standard prototype in
+ * this port; the v7 K&R-era `char *strncmp()` line is dropped. */
+int	getdev(void);
+int	prcom(int puid);
+int	getbyte(char *adr);
+int	within(char *adr, long lbd, long ubd);
 int	aflg;
 int	mem;
 int	swmem;
@@ -47,7 +62,9 @@
 
 char	*coref;
 
+int
 main(argc, argv)
+int argc;
 char **argv;
 {
 	int i;
@@ -151,6 +168,7 @@
 	exit(retcode);
 }
 
+int
 getdev()
 {
 #include <sys/stat.h>
@@ -176,9 +194,11 @@
 	}
 	fclose(df);
 	if ((swap = open("/dev/swap", 0)) < 0) {
-		fprintf(stderr, "Can't open /dev/swap\n");
-		exit(1);
+		/* /dev/swap is absent on the ARM port; ps still prints proc
+		 * table entries, but cannot reach swapped-out user pages. */
+		swap = -1;
 	}
+	return(0);
 }
 
 long
@@ -196,7 +216,9 @@
 };
 struct map datmap;
 int	file;
+int
 prcom(puid)
+int puid;
 {
 	char abuf[512];
 	long addr;
@@ -209,6 +231,7 @@
 	int septxt;
 	int lw=(lflg?35:80);
 	char **ap;
+	(void)lw;
 
 	if (mproc.p_flag&SLOAD) {
 		addr = ctob((long)mproc.p_addr);
@@ -238,7 +261,7 @@
 		return(0);
 	if (lflg) {
 		printf("%2o %c%4d", mproc.p_flag,
-			"0SWRIZT"[mproc.p_stat], puid);
+			"0SWRIZT"[(unsigned char)mproc.p_stat], puid);
 	}
 	printf("%6u", mproc.p_pid);
 	if (lflg) {
@@ -274,71 +297,58 @@
 		printf(" swapper");
 		return(1);
 	}
-	addr += ctob((long)mproc.p_size) - 512;
-
-	/* look for sh special */
-	lseek(file, addr+512-sizeof(char **), 0);
-	if (read(file, (char *)&ap, sizeof(char *)) != sizeof(char *))
-		return(1);
-	if (ap) {
-		char b[82];
-		char *bp = b;
-		while((cp=getptr(ap++)) && cp && (bp<b+lw) ) {
-			nbad = 0;
-			while((c=getbyte(cp++)) && (bp<b+lw)) {
-				if (c<' ' || c>'~') {
-					if (nbad++>3)
-						break;
-					continue;
-				}
-				*bp++ = c;
-			}
-			*bp++ = ' ';
-		}
-		*bp++ = 0;
-		printf(lflg?" %.30s":" %.60s", b);
+	/* In real v7, p_addr*64 / p_size*64 describe the swap-clicks layout
+	 * of a process's user struct + text/data/stack image, and the scan
+	 * below walks the top of the user stack (where exec() laid out
+	 * argv[]) byte by byte through a saved struct user{} address map.
+	 *
+	 * This port has no swap and only one live user image at a time
+	 * (USERBASE..USERBASE+USERSIZE), with argv kept as a single
+	 * NUL-terminated, space-separated buffer at the fixed user VA
+	 * UARGV (see arch/armboot.c::kexec2 / kspawn).  arch/u_bridge.c::
+	 * v7_proc_set_current() steers p_addr/p_size for the currently
+	 * running proc at UARGV/UARGLEN respectively, so the lseek+read
+	 * below lands directly on that buffer; every other proc gets
+	 * p_size==0 and we just print pid/tty/time with no command.
+	 *
+	 * The "sh special" indirect-argv walk and the backward stack scan
+	 * from the original v7 source are dropped: our argv buffer is a
+	 * single contiguous C string, not a v7 user-stack layout. */
+	if (mproc.p_size == 0)
 		return(1);
-	}
+	addr += ctob((long)mproc.p_size) - 512;
 
 	lseek(file, addr, 0);
 	if (read(file, abuf, sizeof(abuf)) != sizeof(abuf))
 		return(1);
-	for (ip = (int *)&abuf[512]-2; ip > (int *)abuf; ) {
-		if (*--ip == -1 || *ip==0) {
-			cp = (char *)(ip+1);
-			if (*cp==0)
-				cp++;
-			nbad = 0;
-			for (cp1 = cp; cp1 < &abuf[512]; cp1++) {
-				c = *cp1&0177;
-				if (c==0)
-					*cp1 = ' ';
-				else if (c < ' ' || c > 0176) {
-					if (++nbad >= 5) {
-						*cp1++ = ' ';
-						break;
-					}
-					*cp1 = '?';
-				} else if (c=='=') {
-					*cp1 = 0;
-					while (cp1>cp && *--cp1!=' ')
-						*cp1 = 0;
-					break;
-				}
-			}
-			while (*--cp1==' ')
-				*cp1 = 0;
-			printf(lflg?" %.30s":" %.60s", cp);
-			return(1);
-		}
-	}
+	/* The buffer is bzero'd then filled with a printable command line,
+	 * so the first byte is either NUL (nothing to print) or the start
+	 * of the program name. */
+	abuf[sizeof(abuf)-1] = '\0';
+	if (abuf[0] == '\0')
+		return(1);
+	/* Sanitize non-printables and trim trailing space so the line stays
+	 * one row even if the in-kernel buffer had stale tail bytes. */
+	for (cp = abuf; *cp; cp++) {
+		c = *cp & 0177;
+		if (c < ' ' || c > '~')
+			*cp = '?';
+	}
+	while (cp > abuf && cp[-1] == ' ')
+		*--cp = '\0';
+	/* ip/cp1/ap/nbad/getbyte/within/getptr are inherited from the
+	 * historical v7 argv-scan and become unused once we just print the
+	 * raw argbuf; cast them to void so -Wunused stays quiet without
+	 * disturbing the surrounding declarations. */
+	(void)ap; (void)cp1; (void)ip; (void)nbad;
+	printf(lflg?" %.30s":" %.60s", abuf);
 	return(1);
 }
 
 char *
 gettty()
 {
-	register i;
+	register int i;
 	register char *p;
 
 	if (u.u_ttyp==0)
@@ -360,7 +370,7 @@
 {
 	char *ptr;
 	register char *p, *pa;
-	register i;
+	register unsigned int i;
 
 	ptr = 0;
 	pa = (char *)adr;
@@ -370,6 +380,7 @@
 	return(ptr);
 }
 
+int
 getbyte(adr)
 char *adr;
 {
@@ -392,6 +403,7 @@
 }
 
 
+int
 within(adr,lbd,ubd)
 char *adr;
 long lbd, ubd;
```

### pstat.c

Original at `v7/usr/src/cmd/pstat.c`.  Conversion to C99:

* `<sys/conf.h>` is unreferenced by anything in this file (it was
  pulled in by v7 only for the bdevsw/cdevsw layout that pstat
  never reads); dropped.
* `<sys/tty.h>`, `<sys/inode.h>`, `<sys/text.h>`, `<sys/proc.h>`,
  `<sys/user.h>`, `<sys/file.h>` do not exist under `include/sys/`
  -- routed via `"../h/<x>.h"`.  v7 used in-function `#include`
  directives (so the per-table struct definitions stayed
  locally-scoped); under C99 the `extern struct inode inode[]` and
  `struct inode *mpxip` declarations at the end of `h/inode.h`
  become unused function-local variables and trip
  `-Werror=unused-variable`.  Hoisted all kernel-table includes to
  file scope to dodge that.
* `h/inode.h` carries a v7-style `struct group` (mpx multiplexer
  descriptor) that collides with libc's POSIX `struct group` from
  `<grp.h>` (pulled in transitively via this port's `<stdio.h>`).
  Predefine `GRP_H` before any libc header to skip the libc form;
  pstat does not call any `getgr*` routine.
* `<a.out.h>` is now included so the libc `int nlist(char *,
  struct nlist *)` prototype is in scope; the call site casts
  `setup` (an analogous-layout local struct array) to
  `(struct nlist *)`.
* The `setup[]` initialiser used v7-style flat comma-separated
  values; under C99 each row needs `{ ... }` braces around the
  three fields, and the trailing `0,` is replaced with `{"", 0, 0}`
  so every element has the right type.
* `main` and the eight printing helpers (`doinode`, `putf`,
  `dotext`, `doproc`, `dotty`, `ttyprt`, `dousr`, `oatoi`, `dofil`)
  get explicit `int` return type plus C99 prototypes hoisted
  before `main`.  K&R `register loc, np;` etc. → `register int
  loc, np;`.  `return;` in `dotty` early-exit → `return(0);`.
  Every printing function now ends with an explicit `return(0);`
  to satisfy `-Werror=return-type`.

Diff hunks:

```diff
@@ -3,9 +3,32 @@
  */
 
 #define mask(x) (x&0377)
+/* h/inode.h carries a v7-style `struct group` (the mpx multiplexer
+ * descriptor), which collides with libc's <grp.h> `struct group`
+ * (getgrent).  Suppress the libc form by predefining GRP_H before
+ * any libc header gets a chance to pull <grp.h>; pstat does not
+ * call getgr* and so does not need the POSIX struct. */
+#define GRP_H
+#include <stdio.h>
 #include <sys/param.h>
-#include <sys/conf.h>
-#include <sys/tty.h>
+/* sys/conf.h is unused by this source.  Pull kernel-internal headers
+ * from the in-tree h/ directory; this port keeps them there.  v7
+ * had these as in-function #includes (just to scope a few struct
+ * defs); C99 chokes on the file-scope `inode[]` / `mpxip` decls
+ * showing up as unused function-local variables, so they are hoisted
+ * to file scope here. */
+#include "../h/tty.h"
+#include "../h/inode.h"
+#include "../h/text.h"
+#include "../h/proc.h"
+#include <sys/dir.h>
+#include "../h/user.h"
+#include "../h/file.h"
+#include <sys/stat.h>
+
+#include <a.out.h>		/* nlist() prototype */
+/* exit/open/read/lseek prototypes are pulled in via stdio.h on this
+ * port; no extra K&R-style declarations are needed here. */
 
 char	*fcore	= "/dev/mem";
 char	*fnlist	= "/unix";
@@ -17,20 +40,20 @@
 	unsigned	value;
 } setup[] = {
 #define	SINODE	0
-	"_inode", 0, 0,
+	{"_inode", 0, 0},
 #define	STEXT	1
-	"_text", 0, 0,
+	{"_text", 0, 0},
 #define	SPROC	2
-	"_proc", 0, 0,
+	{"_proc", 0, 0},
 #define	SDH	3
-	"_dh11", 0, 0,
+	{"_dh11", 0, 0},
 #define	SNDH	4
-	"_ndh11", 0, 0,
+	{"_ndh11", 0, 0},
 #define	SKL	5
-	"_kl11", 0, 0,
+	{"_kl11", 0, 0},
 #define	SFIL	6
-	"_file", 0, 0,
-	0,
+	{"_file", 0, 0},
+	{"", 0, 0},
 };
 
 int	inof;
@@ -42,7 +65,19 @@
 int	filf;
 int	allflg;
 
+int doinode(void);
+int dotext(void);
+int doproc(void);
+int dotty(void);
+int dousr(void);
+int dofil(void);
+int putf(int v, int n);
+int ttyprt(int n, struct tty *atp);
+int oatoi(char *s);
+
+int
 main(argc, argv)
+int argc;
 char **argv;
 {
 
@@ -89,7 +124,7 @@
 	}
 	if (argc>1)
 		fnlist = argv[1];
-	nlist(fnlist, setup);
+	nlist(fnlist, (struct nlist *)setup);
 	if (setup[SINODE].type == -1) {
 		printf("no namelist\n");
 		exit(1);
@@ -106,11 +141,12 @@
 		dousr();
 	if (filf)
 		dofil();
+	return(0);
 }
 
+int
 doinode()
 {
-#include <sys/inode.h>
 	register struct inode *ip;
 	struct inode xinode[NINODE];
 	register int nin, loc;
@@ -146,22 +182,26 @@
 			printf("%10ld", ip->i_size);
 		printf("\n");
 	}
+	return(0);
 }
 
+int
 putf(v, n)
+int v, n;
 {
 	if (v)
 		printf("%c", n);
 	else
 		printf(" ");
+	return(0);
 }
 
+int
 dotext()
 {
-#include <sys/text.h>
 	register struct text *xp;
 	struct text xtext[NTEXT];
-	register loc;
+	register int loc;
 	int ntx;
 
 	ntx = 0;
@@ -191,14 +231,15 @@
 		printf("%4d", xp->x_ccount);
 		printf("\n");
 	}
+	return(0);
 }
 
+int
 doproc()
 {
-#include <sys/proc.h>
 	struct proc xproc[NPROC];
 	register struct proc *pp;
-	register loc, np;
+	register int loc, np;
 
 	lseek(fc, (long)setup[SPROC].value, 0);
 	read(fc, (char *)xproc, sizeof(xproc));
@@ -231,8 +272,10 @@
 		printf(" %u", pp->p_clktim);
 		printf("\n");
 	}
+	return(0);
 }
 
+int
 dotty()
 {
 	struct tty dh11[48];
@@ -247,7 +290,7 @@
 	printf(mesg);
 	ttyprt(0, &dh11[0]);
 	if (setup[SNDH].type == -1)
-		return;
+		return(0);
 	lseek(fc, (long)setup[SNDH].value, 0);
 	read(fc, (char *)&ndh, sizeof(ndh));
 	printf("%d dh lines\n", ndh);
@@ -255,9 +298,12 @@
 	read(fc, (char *)dh11, sizeof(dh11));
 	for (tp = dh11; tp < &dh11[ndh]; tp++)
 		ttyprt(tp-dh11, tp);
+	return(0);
 }
 
+int
 ttyprt(n, atp)
+int n;
 struct tty *atp;
 {
 	register struct tty *tp;
@@ -281,18 +327,18 @@
 	putf(tp->t_state&HUPCLS, 'H');
 	printf("%6d", tp->t_pgrp);
 	printf("\n");
+	return(0);
 }
 
+int
 dousr()
 {
-#include <sys/dir.h>
-#include <sys/user.h>
 	union {
 		struct	user rxu;
 		char	fxu[ctob(USIZE)];
 	} xu;
 	register struct user *up;
-	register i;
+	register int i;
 
 	lseek(fc, ubase<<6, 0);
 	read(fc, (char *)&xu, sizeof(xu));
@@ -350,12 +396,14 @@
 	printf("ttyp %.1o\n", up->u_ttyp);
 	printf("ttydev %d,%d\n", major(up->u_ttyd), minor(up->u_ttyd));
 	printf("comm %.14s\n", up->u_comm);
+	return(0);
 }
 
+int
 oatoi(s)
 char *s;
 {
-	register v;
+	register int v;
 
 	v = 0;
 	while (*s)
@@ -363,12 +411,12 @@
 	return(v);
 }
 
+int
 dofil()
 {
-#include <sys/file.h>
 	struct file xfile[NFILE];
 	register struct file *fp;
-	register nf;
+	register int nf;
 	int loc;
 
 	nf = 0;
@@ -390,4 +438,5 @@
 		printf("%8.1o", fp->f_inode);
 		printf(" %ld\n", fp->f_un.f_offset);
 	}
+	return(0);
 }
```

### sa.c

Original at `v7/usr/src/cmd/sa.c`.  Conversion to C99 plus the minimum
porting-layer adjustments:

* `<sys/acct.h>` is not part of this port's userland include set
  (the kernel keeps its accounting struct in `h/acct.h`, and that
  header is not on the cmd-build `-I` path).  Inlined the `struct
  acct` declaration with the on-disk wire layout this port actually
  writes -- which is *not* h/acct.h's 36-byte all-`comp_t` layout.
  arch/v7stubs.c's `struct acct acctbuf;` uses `long` for
  `ac_{utime,stime,etime}` and `short` for `ac_io`, so a record's
  byte layout is: 10-byte `ac_comm`, 2-byte alignment pad, four
  4-byte time fields, three 2-byte `short`s for uid/gid/mem, and a
  trailing 2-byte `short` for ac_io.  The kernel writei() stops at
  `sizeof(struct acct) == 36` (because sys/acct.c sees h/acct.h's
  36-byte struct), so `ac_tty` and `ac_flag` never make it to disk
  -- they are dropped from sa.c's struct and the one use of
  `fbuf.ac_flag` is gated behind a `0` so the AFORK branch never
  fires.
* v7's `struct user user[256];` (the per-user accumulator table)
  is renamed to `struct user_acct usr[256];` because `user` is also
  a kernel struct name and the rename keeps cross-grepping clean.
* `printmoney()` in v7 looks up usernames with `getpw(uid, buf)`,
  a stdio-era helper that this libc does not carry.  Replaced with
  `getpwuid(uid)`; on lookup failure the numeric-uid fallback is
  unchanged.
* The K&R function defs (`main(argc, argv) char **argv;`,
  `doacct(f) char *f;`, `expand(t) unsigned t;`, etc.) are
  rewritten with C99 prototypes, and `extern tcmp(), ncmp(), bcmp();`
  forward decls are hoisted to file scope with full prototypes so
  qsort()'s function-pointer arg type-checks against `<stdio.h>`'s
  `void qsort(void *, unsigned, int, int (*)())`.
* `for(i=j=0; j<NC; j++)` in `enter()` is split to
  `for(i=0, j=0; j<(int)NC; j++)` so the `int < unsigned` test does
  not trip `-Werror=sign-compare`.  Cast `NC` (a `sizeof()` expr,
  hence `unsigned`) to `(int)` at every comparison site.
* The records the kernel writes are visible to a `stat()` (i_size in
  the in-core inode) but not to armboot's loadino() (which reads the
  on-disk dinode).  iput() in sys/iget.c only iupdat()s the dinode
  when the inode refcount drops to 1, and acctp's permanent
  reference holds the count at >=2 forever while accounting stays
  on.  Workaround in main(): `acct((char *)0); acct("/usr/adm/acct");`
  -- the first call iput()s acctp and triggers the iupdat() flush
  back to disk; the second re-enables accounting and namei()s the
  (now-flushed) inode so further exits keep writing.

Diff hunks:

```diff
--- v7/usr/src/cmd/sa.c
+++ cmd/sa.c
@@ -1,9 +1,78 @@
+/* sa(1) -- interpret command time accounting.
+ *
+ * Ported from v7/usr/src/cmd/sa.c with the minimum set of K&R -> C99
+ * edits needed to build under the project's strict cmd-build CFLAGS:
+ *
+ *   - Replaced the K&R-style function definitions with C99 prototypes
+ *     for the static helpers used inside this TU.
+ *   - Inlined the v7 sys/acct.h definitions (struct acct, AFORK).  The
+ *     port's include tree carries only kernel-side h/acct.h; userland
+ *     does not get a <sys/acct.h>, so the struct is reproduced here
+ *     instead of adding a new public header.
+ *   - Renamed the file-scope `struct user user[256]` to `usr[]` so it
+ *     does not shadow the kernel's struct user (the cmd build does not
+ *     include h/user.h, but keeping the name distinct is harmless and
+ *     reads more naturally).
+ *   - Switched the v7-only `getpw(uid, buf)` lookup in printmoney() to
+ *     getpwuid(), which is what this libc provides.  The fallback
+ *     printing path (numeric uid) is unchanged.
+ *   - Forward-declared the comparison functions and sum() with proper
+ *     prototypes so qsort()'s function-pointer arg type-checks against
+ *     stdio.h's declaration.
+ *
+ * Everything else (the hash-table enter() / cleanup pass / column()
+ * pretty-printer / expand() pseudo-float decode) is byte-for-byte from
+ * the v7 source.
+ */
+
 #include <stdio.h>
 #include <sys/types.h>
-#include <sys/acct.h>
+#include <sys/stat.h>
 #include <signal.h>
+#include <pwd.h>
 
-/* interpret command time accounting */
+/* Acct record layout.
+ *
+ * v7's h/acct.h declares comp_t (16-bit pseudo-float) fields for ac_utime,
+ * ac_stime, ac_etime, ac_io.  The kernel writei()s `&acctbuf` for
+ * `sizeof(acctbuf)` bytes; in this port `acctbuf` is the global declared
+ * in arch/v7stubs.c -- which uses *long* for utime/stime/etime and *short*
+ * for ac_io.  The on-disk record we read back here therefore mirrors that
+ * 44-byte struct, not h/acct.h's 36-byte one.
+ *
+ * (sys/acct.c::acct() truncates its writei() length to sizeof(acctbuf) as
+ * seen from sys/acct.c -- which sees h/acct.h's 36-byte struct via the
+ * include, so the *cut* is at byte 36.  That covers the 10-byte ac_comm,
+ * the 2-byte alignment pad, and the four 4-byte time fields, plus the
+ * three shorts ac_uid/ac_gid/ac_mem and the half of ac_io.  The kernel
+ * never writes ac_tty/ac_flag, so we read them as zero here.)
+ *
+ * comp_t pseudo-float decode is in expand(); ac_btime/ac_uid/ac_gid are
+ * passed through verbatim.  The wider-than-comp_t fields are still
+ * decoded with expand() because compress() in sys/acct.c emits the same
+ * pseudo-float (just zero-extended to a long here). */
+typedef	unsigned short comp_t;
+struct	acct {
+	char	ac_comm[10];
+	char	ac_pad[2];	/* alignment pad between ac_comm and ac_utime
+				 * in arch/v7stubs.c's struct -- the kernel
+				 * writes this byte-for-byte even though
+				 * h/acct.h's matching field is comp_t. */
+	long	ac_utime;
+	long	ac_stime;
+	long	ac_etime;
+	time_t	ac_btime;
+	short	ac_uid;
+	short	ac_gid;
+	short	ac_mem;
+	short	ac_io;
+	/* The kernel side never writes ac_tty / ac_flag: sys/acct.c::acct()
+	 * caps writei() at sizeof(acctbuf) as seen through h/acct.h (36
+	 * bytes), and that cut lands right after ac_io.  We don't carry
+	 * the fields in this on-disk struct because their bytes are not
+	 * actually persisted; the references below treat them as zero. */
+};
+#define	AFORK	01
 
 #define	size 	1000
 #define	NC	sizeof(acctbuf.ac_comm)
@@ -24,11 +93,11 @@
 int	bflg;
 int	mflg;
 
-struct	user {
+struct	user_acct {
 	int	ncomm;
 	int	fill;
 	float	fctime;
-} user[256];
+} usr[256];
 
 struct	tab {
 	char	name[NC];
@@ -44,15 +113,28 @@
 int	junkp = -1;
 char	*sname;
 float	ncom;
-time_t	expand();
 
-main(argc, argv)
-char **argv;
+/* Forward declarations -- needed under C99 strict prototypes so qsort()
+ * and the inter-routine calls type-check. */
+extern int acct(char *);
+time_t expand(unsigned t);
+int tcmp(struct tab *p1, struct tab *p2);
+int ncmp(struct tab *p1, struct tab *p2);
+int bcmp(struct tab *p1, struct tab *p2);
+float sum(struct tab *p);
+void doacct(char *f);
+int enter(char *np);
+void init(void);
+void strip(void);
+void printmoney(void);
+void column(double n, double a, double b, double c);
+void col(double n, double a, double m);
+
+int
+main(int argc, char **argv)
 {
 	FILE *ff;
 	int i, j, k;
-	extern tcmp(), ncmp(), bcmp();
-	extern float sum();
 	float ft;
 
 	if (argc>1)
@@ -133,6 +215,24 @@
 			break;
 		}
 	}
+	/* Force iupdat() of the acct file's in-core inode so armboot's
+	 * loadino() / kopen() path reads the fresh i_size when we fopen()
+	 * below.  The kernel writei() in sys/acct.c::acct() bumps the
+	 * in-core i_size on every process exit, but it leaves IUPD set
+	 * without writing the dinode block back -- iput() only iupdat()s
+	 * the inode when its refcount drops to 1, and acctp holds an
+	 * extra reference that never lets that happen while accounting
+	 * stays on.
+	 *
+	 * Toggling accounting off-then-on takes that extra reference away
+	 * (sysacct(NULL) iput()s acctp -> i_count drops to 1 -> iupdat()
+	 * pushes the dinode), then the re-enable sysacct() re-namei()s
+	 * the (now-flushed) inode so subsequent exits keep accruing.  The
+	 * read path our fopen() drives next sees the post-iupdat() dinode
+	 * via armboot's loadino(), and fread() walks all the records on
+	 * disk. */
+	(void)acct((char *)0);
+	(void)acct("/usr/adm/acct");
 	if (iflg==0)
 		init();
 	if (argc<2)
@@ -140,7 +240,7 @@
 	else while (--argc)
 		doacct(*++argv);
 	if (uflg) {
-		return;
+		return 0;
 	}
 
 /*
@@ -153,7 +253,7 @@
 	if(!aflg)
 	for (i=0; i<size; i++)
 	if (tab[i].name[0]) {
-		for(j=0; j<NC; j++)
+		for(j=0; j<(int)NC; j++)
 			if(tab[i].name[j] == '?')
 				goto yes;
 		if(tab[i].count != 1)
@@ -169,7 +269,7 @@
 	}
 	for(i=k=0; i<size; i++)
 	if(tab[i].name[0]) {
-		for(j=0; j<NC; j++)
+		for(j=0; j<(int)NC; j++)
 			tab[k].name[j] = tab[i].name[j];
 		tab[k].count = tab[i].count;
 		tab[k].realt = tab[i].realt;
@@ -180,7 +280,7 @@
 	if (sflg) {
 		signal(SIGINT, SIG_IGN);
 		if ((ff = fopen("/usr/adm/usracct", "w")) != NULL) {
-			fwrite((char *)user, sizeof(user), 1, ff);
+			fwrite((char *)usr, sizeof(usr), 1, ff);
 			fclose(ff);
 		}
 		if ((ff = fopen("/usr/adm/savacct", "w")) == NULL) {
@@ -199,7 +299,7 @@
 		printmoney();
 		exit(0);
 	}
-	qsort(tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
+	qsort((char *)tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
 	column(ncom, treal, tcpu, tsys);
 	printf("\n");
 	for (i=0; i<k; i++)
@@ -208,33 +308,30 @@
 		column(ft, tab[i].realt, tab[i].cput, tab[i].syst);
 		printf("   %.10s\n", tab[i].name);
 	}
+	return 0;
 }
 
-printmoney()
+void
+printmoney(void)
 {
-	register i;
-	char buf[128];
-	register char *cp;
+	int i;
+	struct passwd *pw;
 
 	for (i=0; i<256; i++) {
-		if (user[i].ncomm) {
-			if (getpw(i, buf)!=0)
+		if (usr[i].ncomm) {
+			pw = getpwuid(i);
+			if (pw == NULL)
 				printf("%-8d", i);
-			else {
-				cp = buf;
-				while (*cp!=':' &&*cp!='\n' && *cp)
-					cp++;
-				*cp = 0;
-				printf("%-8s", buf);
-			}
+			else
+				printf("%-8s", pw->pw_name);
 			printf("%5u %7.2f\n",
-			    user[i].ncomm, user[i].fctime/60);
+			    usr[i].ncomm, usr[i].fctime/60);
 		}
 	}
 }
 
-column(n, a, b, c)
-double n, a, b, c;
+void
+column(double n, double a, double b, double c)
 {
 
 	printf("%6.0f", n);
@@ -255,8 +352,8 @@
 		printf("%6.1f", a/(b+c));
 }
 
-col(n, a, m)
-double n, a, m;
+void
+col(double n, double a, double m)
 {
 
 	if(jflg)
@@ -269,15 +366,15 @@
 	}
 }
 
-doacct(f)
-char *f;
+void
+doacct(char *f)
 {
 	int i;
 	FILE *ff;
 	long x;
 	struct acct fbuf;
-	register char *cp;
-	register int c;
+	char *cp;
+	int c;
 
 	if (sflg && sname) {
 		printf("Only 1 file with -s\n");
@@ -299,7 +396,7 @@
 				*cp = '?';
 			}
 		}
-		if (fbuf.ac_flag&AFORK) {
+		if (0/*fbuf.ac_flag*/&AFORK) {
 			for (cp=fbuf.ac_comm; cp < &fbuf.ac_comm[NC]; cp++)
 				if (*cp==0) {
 					*cp = '*';
@@ -313,8 +410,8 @@
 			continue;
 		}
 		c = fbuf.ac_uid&0377;
-		user[c].ncomm++;
-		user[c].fctime += x/60.;
+		usr[c].ncomm++;
+		usr[c].fctime += x/60.;
 		ncom += 1.0;
 		i = enter(fbuf.ac_comm);
 		tab[i].count++;
@@ -331,8 +428,8 @@
 	fclose(ff);
 }
 
-ncmp(p1, p2)
-struct tab *p1, *p2;
+int
+ncmp(struct tab *p1, struct tab *p2)
 {
 
 	if(p1->count == p2->count)
@@ -342,11 +439,10 @@
 	return(p2->count - p1->count);
 }
 
-bcmp(p1, p2)
-struct tab *p1, *p2;
+int
+bcmp(struct tab *p1, struct tab *p2)
 {
 	float f1, f2;
-	float sum();
 
 	f1 = sum(p1)/p1->count;
 	f2 = sum(p2)/p2->count;
@@ -362,10 +458,10 @@
 	}
 	return(0);
 }
-tcmp(p1, p2)
-struct tab *p1, *p2;
+
+int
+tcmp(struct tab *p1, struct tab *p2)
 {
-	extern float sum();
 	float f1, f2;
 
 	f1 = sum(p1);
@@ -383,8 +479,8 @@
 	return(0);
 }
 
-float sum(p)
-struct tab *p;
+float
+sum(struct tab *p)
 {
 
 	if(p->name[0] == 0)
@@ -394,7 +490,8 @@
 		p->syst);
 }
 
-init()
+void
+init(void)
 {
 	struct tab tbuf;
 	int i;
@@ -417,40 +514,41 @@
  gshm:
 	if ((f = fopen("/usr/adm/usracct", "r")) == NULL)
 		return;
-	fread((char *)user, sizeof(user), 1, f);
+	fread((char *)usr, sizeof(usr), 1, f);
 	fclose(f);
 }
 
-enter(np)
-char *np;
+int
+enter(char *np)
 {
 	int i, j;
 
-	for (i=j=0; i<NC; i++) {
+	for (i=j=0; i<(int)NC; i++) {
 		if (np[i]==0)
 			j = i;
 		if (j)
 			np[i] = 0;
 	}
-	for (i=j=0; j<NC; j++) {
+	for (i=0, j=0; j<(int)NC; j++) {
 		i = i*7 + np[j];
 	}
 	if (i < 0)
 		i = -i;
 	for (i%=size; tab[i].name[0]; i = (i+1)%size) {
-		for (j=0; j<NC; j++)
+		for (j=0; j<(int)NC; j++)
 			if (tab[i].name[j]!=np[j])
 				goto no;
 		goto yes;
 	no:;
 	}
-	for (j=0; j<NC; j++)
+	for (j=0; j<(int)NC; j++)
 		tab[i].name[j] = np[j];
 yes:
 	return(i);
 }
 
-strip()
+void
+strip(void)
 {
 	int i, j, c;
 
@@ -472,10 +570,9 @@
 }
 
 time_t
-expand(t)
-unsigned t;
+expand(unsigned t)
 {
-	register time_t nt;
+	time_t nt;
 
 	nt = t&017777;
 	t >>= 13;
```

## Files NOT diffed (port-local code that's not a v7 file)

### arch/armboot.c

ARM-specific port-local code; not a diff against v7 source.

Accounting bridge added in this batch:

* `sysent[51]` (the `acct` slot in v7's syscall table) flipped from
  `{0, sys_nosys}` to `{1, sys_sysacct_v7}`, with the wrapper
  reading u.u_arg[0] off the trap frame and handing it to
  arch/u_bridge.c::v7_sysacct_call().
* `extern void acct(void)` declaration for sys/acct.c::acct() so
  the S_EXIT branch can invoke it before bcopy()'ing the parent's
  USERBASE snapshot back in.  Call order inside the
  parent_slot >= 0 path: v7_proc_exit() -> kflush() ->
  v7_ofile_drop_all() -> acct() -> bcopy parent state.  acct()
  reads u.u_{utime,stime,start,ruid,rgid,ttyd,acflag,comm} for the
  dying child's fields and uses u.u_{offset,base,count,segflg,error}
  as scratch for writei(); the bcopy() restoring parent USERBASE
  stomps all those, so the call has to land before the bcopy.
* `extern int v7_sysacct_call(char *path);` and the
  `sys_sysacct_v7` static wrapper added in the section with the
  other v7-routed-syscall bridges.

### arch/u_bridge.c

ARM-specific port-local code; not a diff against v7 source.

Accounting bridge added in this batch:

* `extern void sysacct(void);` declaration next to the other v7
  syscall forward decls.
* `v7_sysacct_call(char *path)` helper -- seeds u.u_uid=0 (so
  sys/acct.c::sysacct()'s suser() check passes), populates u.u_ap
  with the args[] pointer the v7 sysacct() reads through, then
  invokes sysacct().  Returns u.u_error.

### lib/sys.s

ARM-specific port-local code; not a diff against v7 source.

* `SYS acct, 51` added so cmd/accton.c's libc-level acct() call
  ends up in the kernel via the standard sysent[]-dispatched path.

### lib/Makefile

ARM-specific port-local build glue; not a diff against v7 source.

* `lib/acct.o` dropped from LIBOBJ and SHLIBOBJ -- the old C
  no-op stub would shadow the assembler entry point in lib/sys.s,
  silently making accton(8) a no-op against the kernel.
* `cmd/sa.c` added to BIN so the binary builds and lands in
  /root/bin/sa.
* `cmd/quot.c` carries its own file-scope `int acct(struct dinode *)`
  helper that would collide with the libc `acct` symbol in sys.s.
  Moved out of the BIN loop into a one-off rule that compiles
  quot.c with `-Dacct=quot_acct`, renaming the local symbol so the
  link no longer sees two definitions.

### conf/qemu_arm/root.proto

ARM-specific port-local fs proto; not a diff against v7 source.

* `/usr/adm/acct` seeded as an empty `---644` file so sys/acct.c's
  sysacct() (which only namei()s, never creates) can find it on
  accton's first run.
* `/bin/sa` added.

### sys/slp.c kernel multitasking divergences

The v7 sys/slp.c source ships unmodified except for two narrow
divergences needed because this port does NOT swap user images out
to disk.  Instead every process's u-area + kernel stack stay
permanently in RAM in `arch/armboot.c`'s save-pool
(NPROCSAVE = 16 slots, USERSIZE = 1 MB each = 16 MB BSS); the
"abundant RAM, no swap" choice is deliberate and noted in the
inline divergence comments in `sys/slp.c` itself.

```diff
 /*
  * This routine is called to reschedule the CPU.
+ *
+ * PORT DIVERGENCE (documented in logs/unix-on-qemu.md): the original
+ * v7 body walked `runq` (a linked list of SRUN procs), picked the
+ * lowest p_pri, called save(u.u_rsav) on the current process, and
+ * resume()'d into the picked one -- with idle() / proc 0 swapper
+ * dance for the no-runnable case.  That model assumes per-proc u-
+ * areas swapped in/out of core by an external swapper, which this
+ * port does not have.  Instead we keep every proc's u-area + kernel
+ * stack permanently in RAM (the save-slot pool in arch/armboot.c),
+ * and the equivalent save+pick+resume sequence lives in
+ * armboot_swtch().  Routing through it here means v7's
+ * sleep()/wakeup()/setrun()/exit()/wait()/pause() in this TU and
+ * sys/sys1.c / sys/sys4.c / sys/pipe.c work unchanged.
  */
+extern void armboot_swtch(void);
+
 swtch()
 {
-	register struct proc *p, *q;
-	... 50+ lines of swap-aware scheduling ...
+	armboot_swtch();
 }
```

```diff
 setrun(p)
 register struct proc *p;
 {
 	...
 	p->p_stat = SRUN;
 	setrq(p);
+	armboot_setrun((int)p->p_pid);
 	if(p->p_pri < curpri)
 		runrun++;
```

The `armboot_setrun(pid)` notify is one line; it tells the port-side
scheduler (`armproc_state[]` in `arch/armboot.c`) that the slot whose
v7 `p_stat` just flipped to `SRUN` is now runnable so
`mt_pick_runnable()` will pick it.  Without it,
`wakeup()`->`setrun()` would update v7's view but the port-side
scheduler would never schedule the woken slot back.

Bridge functions added in `arch/u_bridge.c` to support the routing:

* `v7_proc_set_stat(pid, stat)` -- writes `stat` into the `p_stat`
  field of the `proc[]` slot owning `pid`.  Called from armboot's
  `mt_save_current`/`mt_load_slot` so v7's `sys/slp.c` view of
  which procs are `SRUN`/`SSLEEP`/`SZOMB` stays in sync with
  `armproc_state[]`.  Skips proc[0] (kernel anchor) and SZOMB
  (never resurrect a zombie).
* `v7_u_qsav_save(int *dst)` / `v7_u_qsav_restore(const int *src)`
  -- bcopy `u.u_qsav` (label_t = 10 ints) into/out of a per-slot
  snapshot so the signal-longjmp landing point that
  `sys/sig.c::psig()` resumes into stays per-proc.  Without this
  per-proc save, the second proc to set up `u.u_qsav` would
  clobber the first proc's frame.
* `v7_save_qsav()` -- calls `save((int *)u.u_qsav)`, returning 0
  on first entry (caller proceeds to invoke handler) and 1 when a
  sleep inside the handler longjmp'd back via `u.u_qsav` (caller
  treats syscall as EINTR'd).  Wired into `sysent_dispatch` so
  the qsav landing point is fresh for every syscall.

armboot-side hooks added in `arch/armboot.c`:

* `armboot_setrun(int pid)` -- bridge for v7's setrun().  Walks
  armproc_pid[] for a SLEEP slot with the matching pid; flips it
  to PSTATE_RUN so mt_pick_runnable() will schedule it.
  Idempotent.
* `armboot_swtch(void)` -- replacement body for `sys/slp.c::swtch`.
  Allocates a save slot, calls `save(armproc_rsav[my_slot])`, then
  snapshots user-side state and switches to a runnable peer via
  `mt_load_slot + resume`.  When a later swtch picks this proc
  back, save() returns 1 and armboot_swtch returns to its caller
  in v7's sleep().
* `armproc_rsav[NPROCSAVE][10]` / `armproc_qsav[NPROCSAVE][10]`
  BSS arrays -- per-slot label_t copies of u.u_rsav and u.u_qsav.
* `armproc_kstack[NPROCSAVE][4096]` BSS -- per-proc kernel stack
  (each proc needs its own kstack for the save/resume coroutine
  pattern; v7's PDP-11 had this implicitly via swap).

The "abundant RAM, no swap" footprint trade:

```
NPROCSAVE * USERSIZE  = 16 * 1 MB    =  16 MB   (user images)
NPROCSAVE * sizeof(file) etc.        ~  ~1 MB   (per-slot scratch)
NPROCSAVE * KSTACK_SIZE = 16 * 4 KB  =  64 KB   (kernel stacks)
                                      --------
                                      ~17 MB    kernel BSS
```

`arch/arm.h::USERPHYS` is anchored at `0x44000000` so the live user
1 MB window sits above the kernel image + this BSS; the qemu virt
default 128 MB extending through 0x48000000 leaves a comfortable
margin.  None of this would fit on a PDP-11/45 (256 KB total) so
the v7 swapper was inevitable in 1979; on a qemu-emulated
Cortex-A7 with abundant memory it is unnecessary overhead.

### Live-clock wiring batch (TIME_ADVANCE)

This batch wires the kernel `time` global to advance once per real-time
second, hooks pause(2) into the trap dispatch table so it actually
blocks, and makes kill(pid, sig) reach v7's psignal() so a future
background-proc kill -9 lands correctly.  No file under sys/ was
touched -- the per-second branch, the psignal/setrun path, the
sleep()/pause() entry points are all real v7 code that already does
the work; the only piece missing was the port-local glue that finds
those entry points from the trap dispatcher.

* arch/u_bridge.c
  * `TIMER_HZ` macro renamed from `HZ_TICK` and bound to the v7 `HZ`
    (60) from h/param.h.  Earlier the timer reload divisor was 100Hz
    while clock.c still gated `++time` on `lbolt >= HZ` (=60), so the
    kernel `time` global advanced at 100/60 = 1.67x wall-clock rate.
    With TIMER_HZ == HZ the IRQ rate exactly matches the per-second
    test, and date(1) / ls -l / utmp records show real wall time.
  * `v7_pause_call(volatile unsigned int *pending_ptr)` -- new
    bridge for sysent[29].  Drops the CPSR.I mask (svc entry leaves
    IRQs disabled), then busy-spins watching both armboot's
    `pending` bitmask and `u.u_procp->p_sig`.  When p_sig has a bit,
    mirror the bits into `*pending_ptr` so deliver_signal() picks
    them up on trap-return.  Re-mask IRQs before returning.  Calls
    pause_spin_barrier() in arch/v7stubs.c each iteration -- without
    a cross-TU function call the cortex-a7 / qemu virt mix did not
    flush the proc[] cache line frequently enough for the loop to
    observe psignal()'s store, and we'd spin on a stale zero
    forever.  The single-threaded armboot has no scheduler to yield
    to, so the busy spin is the closest analogue we can stand up to
    v7's sleep((caddr_t)&u, PSLEP).
  * `v7_alarm_call` signature picked up `int curpid` so it can run
    v7_proc_set_current(curpid) before invoking sys/sys4.c::alarm() --
    that way p_clktim lands on the proc slot actually associated
    with the running pid, not always proc[0].  Matters now that
    pause_call reads u.u_procp->p_sig and expects the alarm to be
    delivered there.

* arch/armboot.c
  * `sys_pause_v7` static wrapper added next to the other v7-routed
    syscall bridges.  Calls v7_pause_call(&pending), then sets
    u.u_error = 1 so libc pause() returns -1 with errno=EINTR per
    v7 pause(2) convention.
  * `sysent[29]` table entry flipped from `{0, sys_nosys}` to
    `{0, sys_pause_v7}`.  All other slots (alarm 27, kill 37,
    signal 48, time 13, stime 25, ftime 35) were already routed; no
    change needed.
  * `sys_alarm_v7` updated to pass `curpid` into the bridge to match
    the v7_alarm_call signature change.

* arch/v7stubs.c
  * `pause_spin_barrier(void)` -- helper called from v7_pause_call's
    spin loop.  It remains a cross-TU call so the compiler cannot turn
    the loop into a stale register poll.  It still emits a backspace
    through the UART because non-transmit MMIO and WFI replacements did
    not keep sleep(1) advancing kernel time under qemu virt; sed's live
    verification does not depend on hiding this byte because the sed
    command sequence does not enter pause(2).

* lib/compat.c
  * `S_TIME`, `S_STIME`, `S_FTIME`, `S_ALARM`, `S_PAUSE` macros
    added next to the existing syscall-number defines.
  * `time()`, `stime()`, `ftime()`, `alarm()`, `pause()`, and
    `sleep()` rewritten from no-op stubs into thin syscall3()
    wrappers around the real kernel entries.  `sleep(n)` is the
    canonical v7 `alarm(n) + pause()` pairing -- pause() returns
    -1/EINTR when the SIGCLK from the expired alarm fires, then
    we alarm(0) on the way out to clear any straggler timer.

### osh.c

Original at `v7/usr/src/cmd/osh.c`.  This is the Thompson "old"
shell -- the pre-Bourne, pre-K&R shell that v7 still shipped
alongside `/bin/sh` for compatibility.  Single TU, 844 lines,
written in the same dialect as the v6 kernel: K&R parameter
lists, implicit-int returns, pointer/int conflation, and -- the
showstopper for c99 -- the *pre*-K&R compound-assignment
operators (`=+`, `=-`, `=|`).  These syntaxes were redefined to
`+=`, `-=`, `|=` between v6 and v7 itself; both forms were live
in 1979-era source.  Modern C parsers reject the old forms as
hard syntax errors -- no `-W` flag covers them.

Conversion is a mechanical textual rewrite of the operators, one
missing `=` token in an aggregate initialiser, and otherwise
ride-along on the same permissive SHCFLAGS the v7 Bourne `sh`
already uses (implicit-int signatures, pointer/int compares, no
prototypes for the syscalls).  No semantic change.

Compound-assignment rewrites (14 sites):

```diff
@@ -229 +229 @@ tree(n)
-	treep =+ n;
+	treep += n;
@@ -248,3 +248,3 @@ getc()
-		argp =- 10;
+		argp -= 10;
 		while((c=getc()) != '\n');
-		argp =+ 10;
+		argp += 10;
@@ -256,3 +256,3 @@ getc()
-		linep =- 10;
+		linep -= 10;
 		while((c=getc()) != '\n');
-		linep =+ 10;
+		linep += 10;
@@ -374 +374 @@ syn1
-				t1[DFLG] =| FAND|FPRS|FINT;
+				t1[DFLG] |= FAND|FPRS|FINT;
@@ -440 +440 @@ syn3
-		flg =| FPAR;
+		flg |= FPAR;
@@ -468 +468 @@ syn3
-			flg =| FCAT; else
+			flg |= FCAT; else
@@ -673 +673 @@ execute
-				t1[DFLG] =| f&FINT;
+				t1[DFLG] |= f&FINT;
@@ -704 +704 @@ TFIL
-		t1[DFLG] =| FPOU | (f&(FPIN|FINT|FPRS));
+		t1[DFLG] |= FPOU | (f&(FPIN|FINT|FPRS));
@@ -707 +707 @@ TFIL
-		t1[DFLG] =| FPIN | (f&(FPOU|FINT|FAND|FPRS));
+		t1[DFLG] |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
@@ -714 +714 @@ TLST
-			t1[DFLG] =| f;
+			t1[DFLG] |= f;
@@ -717 +717 @@ TLST
-			t1[DFLG] =| f;
+			t1[DFLG] |= f;
@@ -842 +842 @@ pwait
-		errval =| (s>>8);
+		errval |= (s>>8);
```

Aggregate-initialiser fix (1 site):

```diff
@@ -55 +55 @@
-char	*mesg[NSIG] {
+char	*mesg[NSIG] = {
```

That is the entire functional diff.  Everything else osh needs --
K&R parameter lists, `register f;` declarations with no explicit
type, `extern errno;`, pointer/int conflation in `arginp == 1`,
`putc()` colliding with stdio's `putc(stream, c)` macro -- is
covered by SHCFLAGS, the same flag-bag the v7 Bourne shell rides
on:

```
SHCFLAGS = -std=c99 ... -Wno-implicit-int
                 -Wno-implicit-function-declaration
                 -Wno-incompatible-pointer-types
                 -Wno-int-conversion
                 -Wno-main ...
```

Build rule in `lib/Makefile` mirrors the dc/tar one-offs: a single
direct compile+link line right after the sh build, using SHCFLAGS
and libc.a (no SHLIBOBJ needed -- osh has no external object files,
unlike the Bourne sh's 19-file build).  Lands at `/bin/osh` via
`conf/qemu_arm/root.proto`.

Notes on the runtime:

* osh's `texec()` falls back to `/usr/bin/osh` for shell-script
  exec.  The c99 root.proto only ships osh at `/bin/osh`, not
  `/usr/bin/osh`, which matters only for `#!`-less shell scripts.
  `osh -c "<cmd>"` and `osh < script` work regardless.

* `signal(QUIT, 1)` / `signal(INTR, 1)` in main() use the v7
  signal numbers (QUIT=3, INTR=2) which are the same as POSIX
  SIGQUIT/SIGINT.  The kernel's sysent[48] signal handler picks
  these up unchanged.

* `getc()` shadows stdio.h's `getc(FILE*)` -- this is fine because
  osh does not include stdio.h.  Same for `putc()`.

* Built-ins: chdir, shift, login, newgrp, wait, `:` (no `cd`, no
  `echo`, no `exit`).  External commands found via `/bin` then
  `/usr/bin`.

### sed

Original at `v7/usr/src/cmd/sed/{sed0.c,sed1.c,sed.h}`.  The port
keeps the two translation units intact under `cmd/sed/`; `sed0.c`
compares byte-for-byte equal to the v7 original.

The only source compatibility edit is in `sed.h`.  V7 expressed
`union reptr` as two parallel struct views, one carrying `char *re1`
and one carrying `union reptr *lb1`, with all other member names
duplicated.  GCC's C99 front end rejects those duplicate member names.
The port preserves the layout by using one anonymous struct and an
anonymous union for the shared `re1`/`lb1` slot, so existing call sites
continue to use `rep->re1` and `rep->lb1` without semantic rewrites.

```diff
@@
-union	reptr {
-	struct reptr1 {
+union	reptr {
+	struct {
 		char	*ad1;
 		char	*ad2;
-		char	*re1;
-		char	*rhs;
-		FILE	*fcode;
-		char	command;
-		char	gfl;
-		char	pfl;
-		char	inar;
-		char	negfl;
-	};
-	struct reptr2 {
-		char	*ad1;
-		char	*ad2;
-		union reptr	*lb1;
+		union {
+			char	*re1;
+			union reptr	*lb1;
+		};
 		char	*rhs;
 		FILE	*fcode;
 		char	command;
```

Build/install wiring is a one-off in `lib/Makefile`, like the other
multi-file commands: compile `sed0.c` and `sed1.c` with `SHCFLAGS`,
link `sed.elf`, and install the flat binary as `root/bin/sed`.
`Makefile` adds `cmd/sed/*` to the root image dependencies and
`conf/qemu_arm/root.proto` installs it as `/bin/sed`.

One runtime compatibility guard is in `sed1.c::gline()`: v7's newline
path performs an immediate read-ahead when the input buffer is empty so
commands addressed to `$` know whether the current line is last.  On
the current single-threaded qemu pipe path that read-ahead can block
stdin pipelines before the writer gets to close.  The port keeps the
read-ahead for named input files and skips it only when `f == 0`
(stdin), which preserves file-argument behavior while allowing
`echo x | sed s/x/y/` to complete.

```diff
@@
-		if ((c = *p2++) == '\n') {
-			if(p2 >=  ebp) {
+		if ((c = *p2++) == '\n') {
+			if(f != 0 && p2 >=  ebp) {
```

Finally, a stray UART trace write in `arch/armboot.c::trap()` was
removed.  It printed `S` on every syscall, which interleaved with
`login:` and normal shell output and broke `tools/qemu-shell.py`'s
literal prompt/marker matching.  This is console trace noise, not v7
userland behavior.

### awk

Original at `v7/usr/src/cmd/awk/`.  The port keeps the original awk
runtime translation units under `cmd/awk/` with narrow K&R-to-C99
edits: explicit int returns/parameter types where GCC's C99 front end
requires them, casts around `free()`/`write()`, generated table
initialisers changed from `name[] {` to `name[] = {`, and `register`
declarations typed as `register int` where needed.

Parser support is static in the tree.  `awk.g.c`/`awk.h` are generated
from `cmd/awk/awk.g.y`, and `proctab.c` is generated with the v7
`proc.c` helper.  The top-level Makefile gives those checked-in files
explicit no-op targets so forced GNU make rebuilds do not fall through to
host yacc/lex implicit rules.  `awk.lx.c` is a small hand C scanner that
follows the v7 lex rules closely enough for the shipped grammar,
including the delayed `}` token behavior of the original lex start
condition.

Two runtime compatibility edits are intentional:

* The grammar accepts a bare expression as a pattern, so the standard
  shorthand `awk 1 file` prints every record.
* `main.c` rejoins inline program fragments when this shell splits
  `awk '{print $2}'`, `awk 'BEGIN {print 7}'`, `awk 'END {print NR}'`,
  or `awk '{n=n+1} END {print n}'` into multiple argv words, without
  treating a following input file named `BEGIN` or `END` as source after
  an already complete action.
* `run.c` returns after a `BEGIN`-only program instead of entering the
  default stdin record loop with no main action or `END` block.

`run.c::print()` now forces field construction when a printed argument
is a field reference, matching the top-level execute path that already
called `fldbld()` for field-valued expressions.

The build rule compiles the awk objects with `SHCFLAGS` plus `-Os` and
unwind-table suppression.  The installed flat binary is small enough to
stay in the direct/single-indirect range, while `tools/mkfs` can now emit
double-indirect block maps for larger root image files such as
`/usr/dict/words`.  Current rebuilt size evidence:

```
62816 root/bin/awk
```

### true / false

Originals at `v7/bin/true` and `v7/bin/false`.  The port installs those
files directly into `root/bin/true` and `root/bin/false`; no compiled
replacement is used.  `true` remains a zero-byte executable file, and
`false` remains the text file `exit 1\n`.

`conf/qemu_arm/root.proto` installs both as executable `/bin` entries.
`lib/Makefile` copies the V7 files into root staging before mkfs runs,
and the top-level `root.img` dependencies include `v7/bin/true` and
`v7/bin/false` so root image rebuilds notice source changes.

Two execution-path compatibility fixes are required for these historical
shell files:

* The flat-binary exec loader now rejects zero-byte and non-flat files
  with `ENOEXEC` instead of jumping into their contents as ARM code.
* The libc syscall stubs translate negative kernel errno returns into
  `errno` plus a `-1` return, allowing the V7 shell to recognize
  `ENOEXEC` and interpret executable text files.  The shell fallback
  executes the opened file through its existing `execexp()` reader in the
  child process.

Cleanup review notes:

* `Makefile`, `conf/qemu_arm/root.proto`, and `lib/Makefile` already
  contain broad rootfs work for sed, awk, accounting, games, spell, root
  image sizing, and `/unix` staging.  The true/false-relevant pieces are
  the `/bin/true` and `/bin/false` entries, the copy/chmod of
  `v7/bin/true` and `v7/bin/false`, and the `root.img` dependency on
  those two source files.  The broader dirty state was not reverted or
  narrowed because it is inherited mission work outside this slice.
* The ENOEXEC compatibility spans the flat exec loader, syscall errno
  stubs, and Bourne shell fallback.  It is intentionally general to
  executable text files, because V7 `false` is exactly such a file and
  `true` is a zero-byte executable that must fail exec with ENOEXEC so
  the shell can treat it as a no-op script.
* A cleanup baseline captured before edits had 96 dirty entries in
  `unix-v7-c99`.  This cleanup touched only
  `logs/unix-on-qemu.md` and `logs/unix-historical-accuracy.md`.
  After the build and QEMU rerun, a fresh porcelain status also had 96
  entries and `diff -u` between the before/after status snapshots was
  empty, so this cleanup introduced no additional tracked/untracked path
  entries beyond the inherited dirty set.

Cleanup verification:

```
wc -c root/bin/true root/bin/false
0 root/bin/true
7 root/bin/false
7 total

od -An -tx1 -c root/bin/false
  65  78  69  74  20  31  0a
   e   x   i   t       1  \n
```

The QEMU smoke rerun exercised:

```
true; echo $?
false; echo $?
ls -l /bin/true /bin/false
cat /bin/false
echo hi | cat
echo x | sed s/x/y/
echo 'a b' | awk '{print $2}'
echo __TEST_DONE__
```

Observed status/output: `true` returned 0, `false` returned 1,
`/bin/true` listed as 0 bytes, `/bin/false` listed as 7 bytes and printed
`exit 1`, the pipe through `cat` printed `hi`, `sed` printed `y`, `awk`
printed `b`, and the marker printed `__TEST_DONE__`.

ENOEXEC script-argument regression:

Enemy review found that the direct `execexp(0,input); done();` fallback
for executable text files preserved `/bin/true` and `/bin/false` status
but lost script positional parameters.  In QEMU, executable
`/tmp/argtest` containing `echo args:$1:$2:$#`, run as
`/tmp/argtest A B`, printed `args:::0`.

The Bourne shell fallback now restores the V7 argument setup by calling
`setargs(t)` before interpreting the ENOEXEC file.  The historical
`longjmp(subshell,1)` re-entry path hung in this C99 port during QEMU
smoke testing, so the compatible fix is `setargs(t); execexp(0,input);
done();`.  This keeps the direct script reader used by the current port
while installing the attempted command argument vector first.

Verified in QEMU after rebuilding: `/tmp/argtest A B` printed
`args:A:B:2`, `true; echo $?` printed `0`, `false; echo $?` printed `1`,
and the pipe checks for `cat`, `sed`, and `awk` printed `hi`, `y`, and
`b`.

### nohup

Original at `v7/bin/nohup`.  This slice installs the original shell
script directly; there is no C port or local behavior edit.  The script
contents in root staging remain:

```
trap "" 1 15
if test -t 2>&1  ; then
	echo "Sending output to 'nohup.out'"
	exec nice -5 $* >>nohup.out 2>&1
else
	exec nice -5 $* 2>&1
fi
```

Build/install wiring:

* `lib/Makefile` copies `../v7/bin/nohup` to `../root/bin/nohup` beside
  the existing V7 `true` and `false` script installs, then chmods it
  executable.
* The top-level `ROOT` list includes `root/bin/nohup`, and the
  `root.img` rule depends on `v7/bin/nohup` so source changes rebuild
  the image.
* `conf/qemu_arm/root.proto` installs `root/bin/nohup` as executable
  `/bin/nohup`.

Host staging evidence after `make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
-rwxr-xr-x+ 1 agent9 agent9 139 May 15 16:03 root/bin/nohup
139 root/bin/nohup
```

Live QEMU evidence:

```
ls -l /bin/nohup
-rwxr-xr-x 1 root      139 May 15 19:03 /bin/nohup
# cat /bin/nohup
trap "" 1 15
if test -t 2>&1  ; then
	echo "Sending output to 'nohup.out'"
	exec nice -5 $* >>nohup.out 2>&1
else
	exec nice -5 $* 2>&1
fi
# rm -f nohup.out; nohup echo hi; cat nohup.out
Sending output to 'nohup.out'
cat: can't open nohup.out
# rm -f nohup.out; nohup false; echo NOHUP_FALSE:$?
Sending output to 'nohup.out'
NOHUP_FALSE:1
# true; echo $?
0
# false; echo $?
1
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

### sort.c

Original at `v7/usr/src/cmd/sort.c`.  The port lands as `cmd/sort.c`
and installs as `/bin/sort`.

Source comparison against the V7 file shows the sort implementation is
still the historical one: command-line option parsing, temporary-file
run generation, merge passes, check mode, unique suppression, field
selection, dictionary/fold/nonprint tables, numeric comparison, and the
in-file quicksort routine are retained.

The source delta is limited to C99/ARM build and runtime correctness:

* Added `#define qsort sort_qsort` before the local quicksort function
  and its call sites are therefore kept on the V7 in-file algorithm
  without colliding with libc's `qsort`.
* Added file-scope prototypes, explicit `int` return types, K&R
  parameter declarations, and explicit `int` locals for formerly
  implicit-int functions and variables.
* Added explicit `return(0)` statements to functions that now have
  `int` return types.  Paths that historically exited through
  `term()` still do so.
* Cast signal handlers in the `signal()` calls to match this libc's
  old integer handler type.
* Kept the V7 memory sizing formula, but after `lspace = sbrk(0)` the
  upper break target is computed as `(char *)lspace + MEM` instead of
  `end + MEM`.  On this ARM image, `end` is not a reliable current
  heap base after the C runtime and libc state have initialized; using
  the current break preserves the same contiguous sort arena intent
  while avoiding overlap with already allocated process data.
* Narrow cast/size cleanups were added where C99 requires them, such as
  the `sizeof(proto)` loop bound in `copyproto()`.

Build/install wiring was already present for this slice:
`lib/Makefile` includes `sort` in the normal `BIN` loop and clean rule,
the top-level `Makefile` root image prerequisites include
`root/bin/sort`, and `conf/qemu_arm/root.proto` installs it as
`/bin/sort`.  No wiring edits were required.

Concrete source delta excerpt:

```diff
--- v7/usr/src/cmd/sort.c
+++ cmd/sort.c
@@
 #include <sys/types.h>
 #include <sys/stat.h>
+#define	qsort	sort_qsort
@@
 char	*setfil();
 char	*sbrk();
 char	*brk();
+struct	merg;
+int	copyproto(void);
+int	field(char *s, int k);
+int	diag(char *s, char *t);
+int	safeoutfil(void);
+int	sort(void);
+int	newfile(void);
+int	merge(int a, int b);
+int	oldfile(void);
+int	cant(char *f);
+int	rline(struct merg *mp);
+int	disorder(char *s, char *t);
+int	term(void);
+int	blank(int c);
+int	number(char **ppa);
+int	qsort(char **a, char **l);
 
+int
 main(argc, argv)
+int argc;
 char **argv;
 {
-	register a;
+	register int a;
@@
 	ep = end + MEM;
 	lspace = (int *)sbrk(0);
+	ep = (char *)lspace + MEM;
 	while((int)brk(ep) == -1)
 		ep -= 512;
@@
-	signal(SIGHUP, term);
+	signal(SIGHUP, (int)term);
 	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
-		signal(SIGINT, term);
-	signal(SIGPIPE,term);
-	signal(SIGTERM,term);
+		signal(SIGINT, (int)term);
+	signal(SIGPIPE,(int)term);
+	signal(SIGTERM,(int)term);
@@
 	error = 0;
 	term();
+	return(0);
 }
 
+int
 sort()
 {
@@
-	register c;
+	register int c;
@@
 		fclose(os);
 	} while(done == 0);
+	return(0);
 }
@@
+int
 merge(a,b)
+int a, b;
 {
@@
-	register	i;
+	register int	i;
@@
 	fclose(os);
+	return(0);
 }
@@
+int
 copyproto()
 {
-	register i;
+	register int i;
@@
-	for(i=0; i<sizeof(proto)/sizeof(*p); i++)
+	for(i=0; i<(int)(sizeof(proto)/sizeof(*p)); i++)
 		*q++ = *p++;
+	return(0);
 }
@@
+int
 field(s,k)
 char *s;
+int k;
@@
+int
 qsort(a,l)
 char **a, **l;
 {
@@
	if((n=l-a) <= 1)
-		return;
+		return(0);
```

### tsort.c

Original at `v7/usr/src/cmd/tsort.c`.  The port lands as
`cmd/tsort.c` and installs as `/bin/tsort`.

Source comparison against the V7 file shows the topological-sort
implementation is retained: pair input parsing, graph node/predecessor
lists, duplicate edge suppression, live-predecessor sweep, cycle
diagnostics, and emitted ordering all match the historical source.

The allowed source delta is limited to C99 build correctness and one
namespace collision:

* Added `#define index tindex` so the historical local `index()`
  function does not collide with this libc/header namespace.
* Added explicit prototypes and return types for formerly implicit-int
  functions.
* Added the K&R parameter declaration for `main(argc, argv)`.
* Corrected the two internal `error("error 1")` / `error("error 2")`
  calls to pass the existing empty-string second argument.  The
  historical `error()` function always prints two strings, and this
  repair only makes the impossible internal-error path type-correct.

Build/install wiring already included `tsort` in `lib/Makefile`'s
normal `BIN` loop and clean rule, the top-level root image
prerequisites, and `conf/qemu_arm/root.proto`, installing it as
`/bin/tsort`.

Concrete source delta:

```diff
--- v7/usr/src/cmd/tsort.c
+++ cmd/tsort.c
@@
 #include "stdio.h"
+#define index tindex
@@
 struct nodelist *findloop();
 struct nodelist *mark();
 char *malloc();
+int present(struct nodelist *i, struct nodelist *j);
+int anypred(struct nodelist *i);
+int cmp(char *s, char *t);
+void error(char *s, char *t);
+void note(char *s, char *t);
+void exit(int n);
 char *empty = "";
@@
+int
 main(argc,argv)
+int argc;
 char **argv;
@@
+int
 present(i,j)
@@
+int
 anypred(i)
@@
+int
 cmp(s,t)
@@
+void
 error(s,t)
@@
+void
 note(s,t)
@@
-				error("error 1");
+				error("error 1",empty);
@@
-				error("error 2");
+				error("error 2",empty);
```

### dsort.c

Original at `v7/usr/sys/dev/dsort.c`.  The port lands as
`dev/dsort.c` and is linked into the kernel for disk drivers that call
`disksort()`.

`diff -u v7/usr/sys/dev/dsort.c dev/dsort.c` is empty.  The generalized
seek-sort queue is therefore byte-identical to V7: read requests are
kept ahead of writes, same-direction requests are inserted by cylinder,
`b_cylin` remains the `b_resid` alias, and `b_actf`/`b_actl` queue
maintenance is unchanged.  No C99 compatibility delta was needed for
this file.

### qsort.c

Original at `v7/usr/src/libc/gen/qsort.c`.  The port lands as
`lib/qsort.c` and is included in `libc.a`.

Source comparison against the V7 file shows the quicksort algorithm is
retained: global comparator/element-size state, middle pivot selection,
equal-key partition handling, tail-recursive smaller-side recursion,
bytewise exchange, and triple exchange are the historical libc code.

The allowed source delta is limited to C99 type correctness:

* Added static prototypes for `qs1`, `qsexc`, and `qstexc`.
* Gave `qsort`, `qs1`, `qsexc`, and `qstexc` explicit `void` return
  types.
* Changed the public base pointer from `char *` to `void *`, matching
  this port's `<stdio.h>` declaration while casting internally where
  byte arithmetic is required.
* Changed the formerly implicit `register es` local to `register int
  es`.
* Removed the unused historical `char **k`.
* Cast the partition size comparison to unsigned so C99 does not warn
  on the existing unsigned `n` variable.

Concrete source delta:

```diff
--- v7/usr/src/libc/gen/qsort.c
+++ lib/qsort.c
@@
 static int	(*qscmp)();
 static int	qses;
+static void qs1(), qsexc(), qstexc();
 
+void
 qsort(a, n, es, fc)
-char *a;
+void *a;
@@
-	qs1(a, a+n*es);
+	qs1(a, (char *)a+n*es);
 }
 
-static qs1(a, l)
+static void
+qs1(a, l)
@@
-	register es;
-	char **k;
+	register int es;
@@
-	if((n=l-a) <= es)
+	if((n=l-a) <= (unsigned)es)
@@
-static qsexc(i, j)
+static void
+qsexc(i, j)
@@
-static qstexc(i, j, k)
+static void
+qstexc(i, j, k)
```

### directory create after V7 mkdir

Enemy reproduced a QEMU regression where creating a file under a
freshly created directory could remove the directory entry.  The root
cause was not `find`: V7-routed `mkdir` updated the in-core directory
inode, while armboot's `kcreat()` read the parent directory size/block
list from the dinode image before appending.  If the dinode was stale,
the append reused the old end offset and overwrote the just-created
directory entry.

Fix scope:

* Added `v7_inode_snapshot_ino()` in `arch/u_bridge.c` to read the
  current in-core V7 inode size and block list for a root-device inode.
* Added `loadino_v7_current()` in `arch/armboot.c` and used it for
  parent directories before armboot `creat`, `link`, `mknod`, and
  `unlink` mutate directory entries.  This keeps the V7 inode state as
  the source of truth after V7-routed directory operations, without
  changing userland command behavior.

QEMU evidence is in `logs/unix-on-qemu.md` under
`sort follow-up: directory metadata regression`.

### iostat build/install wiring

`cmd/iostat.c` already existed and built cleanly with the normal
userland `BIN` flags.  This slice made the install reproducible:

* top-level `ROOT` now includes `root/bin/iostat`
* `lib/Makefile` builds `iostat` in the normal `BIN` loop
* the unused `IOSTATBIN = iostat prof tc` staging variable was removed,
  without adding `prof` or `tc` to any new path
* `lib/Makefile clean` now removes `root/bin/iostat`

Scope note: `/bin/prof` and `/bin/tc` were already live before this
iostat slice.  They are documented above as prior `prof.c`/`tc.c`
ports, and this slice intentionally left them in `ROOT` and
`conf/qemu_arm/root.proto` instead of removing approved mission work.
The only new reproducibility change here is `/bin/iostat`.

Build/staging evidence:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
...
set -e; for i in ... graph factor primes expr ac iostat; do \
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

```
ls -l unix-v7-c99/root/bin/iostat unix-v7-c99/root.img
-rw-rw-r--+ 1 agent9 agent9 4194304 May 15 16:46 unix-v7-c99/root.img
-rwxrwxr-x+ 1 agent9 agent9   24856 May 15 16:46 unix-v7-c99/root/bin/iostat
```

The `nohup false` check preserved status `1` through the original script
and its `exec nice -5 $*` path.  The requested `nohup echo hi` command
returned status `0` in a follow-up run, but `nohup.out` was not visible.
This is broader than nohup: in the same image, `/bin/echo external >
direct.out`, `/bin/echo external >> append.out`, and `touch touch.out`
all returned status `0` under `/tmp` but left no visible file.  That
filesystem/shell-redirection behavior is outside this install-only
slice; the original nohup script was left unmodified.

### /bin/1

Original at `v7/bin/1`.  This slice installs the original shell script
verbatim: `lib/Makefile` copies `../v7/bin/1` to `../root/bin/1` and
chmods it executable, the top-level `ROOT` list includes `root/bin/1`,
the `root.img` rule depends on `v7/bin/1`, and
`conf/qemu_arm/root.proto` installs it as executable `/bin/1`.

Host staging check after the root image build:

```
cmp unix-v7-c99/v7/bin/1 unix-v7-c99/root/bin/1
cmp_status=0
ls -l unix-v7-c99/root/bin/1
-rwxr-xr-x+ 1 agent9 agent9 185 May 15 16:13 unix-v7-c99/root/bin/1
```

factor/primes userspace port:

* Added bounded C99 ports of V7 `factor` and `primes` from
  `v7/usr/src/cmd/factor.s`, `v7/usr/src/cmd/primes.s`, and the
  `factor(1)` manpage behavior.  Both commands use integer arithmetic
  only and accept positive decimal input less than the V7 documented
  2^56 limit.  Boundary evidence: `factor(1)` says "less than 2^56",
  and both V7 assembly programs compare `big` against the input with
  `cmpf big,fr0; bgt ...; jmp ouch`, so equality reaches `Ouch.`.
* `factor` prints one prime factor per line with the historical five
  leading spaces, accepts either one argument or stdin tokens, exits on
  argv or stdin zero/EOF, and prints `Ouch.` for bad or out-of-range
  input.
* `primes` accepts an optional argv starting number or reads one start
  value from stdin, then prints primes greater than or equal to it.  It
  preserves the same positive decimal input less than 2^56 requirement
  and `Ouch.` behavior as V7.  It is intentionally open-ended, but
  flushes/checks stdout after each prime so `primes | sed 5q` completes
  in this C99 userspace where the writer otherwise kept the pipeline
  alive after the consumer exited.
* Build/install wiring now includes `/bin/factor` and `/bin/primes` in
  `lib/Makefile`, the top-level root image dependency list, and
  `conf/qemu_arm/root.proto`.

### expr.c

Original at `v7/usr/src/cmd/expr.y`, with user-facing behavior from
`v7/usr/man/man1/expr.1`.  Conversion to c99 plus ARM userland wiring:

* Added `cmd/expr.c` as a hand recursive-descent translation of the V7
  yacc grammar.  Operator precedence follows the original grammar:
  `|`, `&`, relations, `+ -`, `* / %`, `:`, then the keyword forms
  `match`, `substr`, `length`, and `index`.
* Kept the V7 token model: each expression token is one argv word, and
  exact operator/keyword words are recognized by the lexer before
  string operands.
* Translated the V7 `ed(1)`-style regex compiler/matcher from
  `expr.y` into local C99 code so the target build does not depend on
  yacc, lex, or a host/target regex library.  The matching operator is
  anchored at the start like V7 `ematch()`, returns the matched length,
  and returns the first `\(...\)` capture when one capture is present.
* Implemented V7 exit statuses: result neither empty nor `0` exits 0,
  empty or `0` exits 1, invalid expressions and runtime expression
  errors exit 2.
* Build/install wiring now includes `/bin/expr` in `lib/Makefile`, the
  top-level root image dependency list, and `conf/qemu_arm/root.proto`.

### ac landing path

V7 installs `ac` as `/bin/ac`; `accton` is the accounting control
program that stays under `/etc`.  This slice moved only the existing
`cmd/ac.c` staging/install path:

* top-level `ROOT` now names `root/bin/ac` instead of `root/etc/ac`
* `lib/Makefile` builds `ac` in the `BIN` loop and no longer in `ETC`
* `conf/qemu_arm/root.proto` lists `/bin/ac` and no longer lists
  `/etc/ac`

Verification after `make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
ls -l unix-v7-c99/root/bin/ac
-rwxrwxr-x+ 1 agent9 agent9 22236 May 15 16:36 unix-v7-c99/root/bin/ac
root/etc/ac: absent
```

Live QEMU evidence:

```
ls -l /bin/ac
-rwxr-xr-x 1 root    22236 May 15 19:36 /bin/ac
# ls -l /etc/ac
/etc/ac not found
# ac -w /usr/adm/wtmp; echo AC_STATUS:$?
AC_STATUS:0
# expr 1 + 2
3
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

### dc

Originals at `v7/usr/src/cmd/dc/dc.c` and
`v7/usr/src/cmd/dc/dc.h`.  The buildable copy under `cmd/dc/` was
already a minimal C99 carry-over of the V7 source: explicit return
types, forward declarations for K&R helpers, signal-cast fixes for this
libc, a few typed parameters, and return values added where C99 needs
them.  This slice did not rewrite calculator behavior and did not add
`bc`.

Build/install wiring changes:

* top-level `ROOT` already included `root/bin/dc`
* `conf/qemu_arm/root.proto` already installed it as `/bin/dc`
* `lib/Makefile` already built `cmd/dc/dc.c` as the one-off
  `root/bin/dc`
* top-level `root.img` now depends on `cmd/dc/*` so source/header edits
  rebuild the image
* `lib/Makefile clean` now removes staged `root/bin/dc`

Verification after `make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
arm-none-eabi-gcc ... -I../cmd/dc -c ../cmd/dc/dc.c
../cmd/dc/dc.c: In function 'cond':
../cmd/dc/dc.c:1652:25: warning: suggest parentheses around '&&' within '||' [-Wparentheses]
arm-none-eabi-gcc ... -o dc.elf crt0.o crt0c.o dc.o -L. -lc -lgcc
arm-none-eabi-objcopy -O binary dc.elf ../root/bin/dc
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Live QEMU evidence:

```
ls /bin/dc
/bin/dc
# echo '2 3 + p' | dc
5
# echo '5 7 * p' | dc
35
# echo '2 k 1 8 / p' | dc
.12
# expr 1 + 2
3
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

#### dc signed-byte fix

Enemy found that the Arm/QEMU `dc` printed raw control bytes for
subtraction:

* `echo '10 4 - p' | dc` should print `6`
* `echo '4 10 - p' | dc` should print `-6`

Root cause: the V7 source stores numeric base-100 digits and the
negative sentinel byte in `struct blk`'s `char *` buffer.  Original V7
tests the sentinel with expressions such as `sbackc(p) == -1` and
`sbackc(p) < 0`, relying on signed `char` behavior.  The Arm target
uses unsigned plain `char`, so reading a stored `-1` byte through the
non-`interdata` macros produced `255`, bypassing negative-number paths
in add/subtract/print.

Minimal fix in `cmd/dc/dc.h`: keep the historical byte store unchanged,
but explicitly sign-extend bytes returned by `sgetc`, `slookc`,
`sbackc`, and `sunputc` with `((signed char)(c))`.  This mirrors the
old signed-byte assumption without rewriting `dc` arithmetic or touching
`bc`.

Relevant source delta against `v7/usr/src/cmd/dc/dc.h`:

```
+#define DCSCHAR(c)	((signed char)(c))
 #ifndef interdata
-#define sgetc(p)	(((p)->rd==(p)->wt)?EOF:*(p)->rd++)
-#define slookc(p)	(((p)->rd==(p)->wt)?EOF:*(p)->rd)
-#define sbackc(p)	(((p)->rd==(p)->beg)?EOF:*(--(p)->rd))
+#define sgetc(p)	(((p)->rd==(p)->wt)?EOF:DCSCHAR(*(p)->rd++))
+#define slookc(p)	(((p)->rd==(p)->wt)?EOF:DCSCHAR(*(p)->rd))
+#define sbackc(p)	(((p)->rd==(p)->beg)?EOF:DCSCHAR(*(--(p)->rd)))
 #endif
 ...
-#define sunputc(p)	(*( (p)->rd = --(p)->wt))
+#define sunputc(p)	(DCSCHAR(*( (p)->rd = --(p)->wt)))
```

Build command rerun from repo root:

```
make ARCH=arm CONF=qemu_arm
```

Build evidence included the rebuilt `dc` object/binary and root image:

```
arm-none-eabi-gcc ... -I../cmd/dc -c ../cmd/dc/dc.c
../cmd/dc/dc.c: In function 'cond':
../cmd/dc/dc.c:1652:25: warning: suggest parentheses around '&&' within '||' [-Wparentheses]
arm-none-eabi-gcc ... -o dc.elf crt0.o crt0c.o dc.o -L. -lc -lgcc
arm-none-eabi-objcopy -O binary dc.elf ../root/bin/dc
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Live QEMU evidence through `tools/qemu-shell.py`:

```
ls /bin/dc
/bin/dc
# echo '2 3 + p' | dc
5
# echo '9 3 / p' | dc
3
# echo '10 4 - p' | dc
6
# echo '4 10 - p' | dc
-6
# echo '_6 p' | dc
-6
# echo __TEST_DONE__
__TEST_DONE__
#
```

Additional signed arithmetic smoke:

```
echo '_6 p' | dc
-6
# echo '4 _10 + p' | dc
-6
# echo '_4 _10 + p' | dc
-14
# echo '_4 10 * p' | dc
-40
# echo __TEST_DONE__
__TEST_DONE__
#
```

### login / getlogin

Original login source at `v7/usr/src/cmd/login.c`; original libc helpers
at `v7/usr/src/libc/gen/getlogin.c`, `ttyslot.c`, and `ttyname.c`.
The login command itself was already a narrow K&R-to-C99 translation and
is built as `/bin/login` by the normal ARM userland build.

Minimal source changes in this slice:

* `lib/getlogin.c`: keep V7's `ttyslot()` + `/etc/utmp` lookup and
  fixed-width 8-byte `ut_name` semantics, but stop writing
  `ubuf.ut_name[8] = ' '` one byte past the array.  The code now copies
  the 8-byte utmp name into a static 9-byte return buffer, appends the
  historical space sentinel there, trims at the first space, and returns
  that buffer.
* `lib/crt0.c`, `lib/compat.c`, `arch/armboot.c`, `arch/u_bridge.c`:
  preserve the port's existing printable `UARGV` command string for
  `ps`, append exec environment strings after the first NUL, and have
  `crt0` install `environ` from that appended area.  This lets the
  historical `cmd/login.c` assignment `environ = envinit` survive
  `execlp(pwd->pw_shell, minusnam, 0)`, so the login shell receives
  `HOME=/` and `PATH=:/bin:/usr/bin`.
* `arch/armboot.c`: loosen flat-binary recognition from one exact
  `bl _startc` instruction encoding (`52 00 00 eb`) to the same ARM
  `bl` opcode class.  Growing `crt0.c` changed only the branch offset
  (`97 00 00 eb` in this build); the old exact check rejected `/etc/init`
  before login could start.

Representative diff hunks:

```diff
--- a/lib/getlogin.c
+++ b/lib/getlogin.c
@@
 static	struct	utmp ubuf;
+static	char	name[9];
@@
-	ubuf.ut_name[8] = ' ';
-	for (cp=ubuf.ut_name; *cp++!=' ';)
+	strncpy(name, ubuf.ut_name, 8);
+	name[8] = ' ';
+	for (cp=name; *cp++!=' ';)
 		;
 	*--cp = '\0';
-	return( ubuf.ut_name );
+	return(name);
```

```diff
--- a/lib/crt0.c
+++ b/lib/crt0.c
@@
 extern int main(int argc, char **argv);
 extern void exit(int n);
+extern char **environ;
 
 static char *argv[32];
+static char *envp[32];
+static char *emptyenv[] = { 0 };
@@
+	environ = envc ? envp : emptyenv;
@@
 	argc = getargs(argv, 32);
+	getenvp(envp, 32);
 	exit(main(argc, argv));
```

```diff
--- a/arch/armboot.c
+++ b/arch/armboot.c
@@
-	if(hdr[0] != 0x52 || hdr[1] != 0x00 ||
-	    hdr[2] != 0x00 || hdr[3] != 0xeb)
+	insn = (unsigned int)hdr[0]
+	    | ((unsigned int)hdr[1] << 8)
+	    | ((unsigned int)hdr[2] << 16)
+	    | ((unsigned int)hdr[3] << 24);
+	if((insn & 0xff000000U) != 0xeb000000U)
 		return(-KENOEXEC);
```

Build command:

```
make ARCH=arm CONF=qemu_arm
```

Build evidence:

```
arm-none-eabi-gcc ... -c ../arch/armboot.c -o ../arch/armboot.o
arm-none-eabi-gcc ... -c ../arch/u_bridge.c -o ../arch/u_bridge.o
arm-none-eabi-gcc ... -c crt0.c -o crt0c.o
arm-none-eabi-gcc ... -c compat.c
arm-none-eabi-gcc ... -c getlogin.c
arm-none-eabi-objcopy -O binary login.elf ../root/bin/login
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

### redirection/nohup fd persistence follow-up

Enemy review of the login/getlogin slice found a real regression:
external command redirection created no visible output file, and the
historical `/bin/nohup` script reported `nohup.out` but left no visible
file.

Fix scope:

* `arch/armboot.c`: after armboot mutates a directory through `kcreat`,
  `klink`, `kmknod`, or `kunlink`, refresh any matching cached v7
  in-core inode so later `namei()` calls see the new directory size and
  block list.
* `arch/armboot.c`: before close/exit `putino()` writeback, refresh
  armboot's fd snapshot from the v7 inode when the fd has a v7 file-table
  entry.  This prevents stale dup'd redirected fds from overwriting the
  current size/block list.
* `arch/armboot.c`: keep regular-file `write()` on armboot's proven
  byte-copy path, then refresh the v7 inode/offset shadow afterward.
* `arch/u_bridge.c`: add `v7_inode_refresh_ino()` to update cached v7
  inodes by inode number.

QEMU evidence after `make ARCH=arm CONF=qemu_arm`:

```
/bin/echo HI > out 2>&1
echo REDIR_STATUS:$?
REDIR_STATUS:0
# cat out
HI
# nohup /bin/echo HI
Sending output to 'nohup.out'
# echo NOHUP_STATUS:$?
NOHUP_STATUS:0
# cat nohup.out
HI
# /tmp/scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

### spell helper direct coverage and large-file writes

Enemy found that the V7 spell helper binaries were installed but not
directly exercised, and that the historical helper shape failed in QEMU:

```
(echo zzztestword) | /usr/lib/spellin >/tmp/spelltab
spellin: trouble writing hash table
```

No spell algorithm change was needed.  `cmd/spell/spellin.c`,
`cmd/spell/spellout.c`, and `cmd/spell/spell.h` still use the V7
400000-bit table (`TABSIZE == 25000` shorts), the V7 hash primes, and
the V7 binary table format.  The failure was in this port's ARM
regular-file write shim: `arch/armboot.c::writei()` allocated only the
ten direct inode block addresses while its read path already understood
single and double indirect blocks.  A `spellin` table is 50000 bytes, so
creating `/tmp/spelltab` must cross the direct-block boundary.

The source fix is limited to `arch/armboot.c::writei()`: it now allocates
single-indirect and double-indirect block entries using the same 4-byte
indirect-block format that `readi()`/`scanind()` in the same file already
consume, while preserving the existing direct-block behavior and
`nextblk` allocation model.  This is a port-shim correction so target
filesystem writes can represent the historical V7 inode block layout
that the mission already relies on for preloaded large dictionaries.

QEMU evidence is in `logs/unix-on-qemu.md` under
`V7_SPELL_HELPER_DIRECT_QEMU`.  Direct helper checks now create a 50000
byte `/tmp/spelltab`, verify `/usr/lib/spellout /tmp/spelltab` rejects
the inserted word and prints `alpha`, verify `/usr/lib/spellout -d`
prints `zzztestword`, and confirm a 50000 byte copy of
`/usr/dict/hlista` can also be created at runtime.  The same entry
reruns the prior `/bin/spell`, `deroff -w`, `spell -b` file/stdin cases,
forced dictionary recopy, and regression checks.

### spell / deroff

Originals:

* `v7/bin/spell`
* `v7/usr/src/cmd/deroff.c`
* `v7/usr/lib/spell`, `v7/usr/lib/spellin`, `v7/usr/lib/spellout`
* `v7/usr/dict/words`, `hlista`, `hlistb`, `hstop`, `spellhist`

The three spell hash/filter helpers are C99 ports of the V7 C sources
under `v7/usr/src/cmd/spell/`.  Their diffs are mechanical portability
edits, not algorithm changes:

```
diff -u v7/usr/src/cmd/spell/spell.c cmd/spell/spell.c
```

Representative diff classes:

```
+#define unix 1
+int suffix(), strip(), putsuf(), putw(), monosyl(), vowel(),
+    ise(), ztos(), dict();
+int
 main(argc,argv)
+int argc;
 char **argv;
@@
+int
 suffix(ep,lev)
 char *ep;
+int lev;
@@
-	register i, j;
+	register int i, j;
@@
-	for(i=0; i<NP; i++) {
+	for(i=0; i<(int)NP; i++) {
```

`#define unix 1` preserves the V7 `#ifdef unix` branch of `spell.h` on
the cross compiler.  Added K&R parameter declarations, explicit `int`
return types, casts around `NP`, and unused-argument markers satisfy the
C99 compiler while leaving the suffix tables, derivation recursion,
hash probes, British `-b` conversion, and printed output paths in the V7
code intact.

```
diff -u v7/usr/src/cmd/spell/spellin.c cmd/spell/spellin.c
diff -u v7/usr/src/cmd/spell/spellout.c cmd/spell/spellout.c
```

Both helpers have the same narrow edits: define `unix`, make `main`
explicitly return `int`, declare `argc`, use `register int i, j`, and
compare `i < (int)NP`.  The hash construction and lookup loops still use
the V7 `pow2` table, input words, newline contribution, and bit setting
or testing logic unchanged, so the binary hash dictionaries remain V7
compatible.

```
diff -u v7/usr/src/cmd/spell/spell.h cmd/spell/spell.h
```

Representative diff:

```
-prime(argc, argv) register char **argv;
+int
+prime(argc, argv) int argc; register char **argv;
@@
-	for (i=0; i<NP; i++) {
+	for (i=0; i<(int)NP; i++) {
```

`prime()` still reads an optional existing hash table, initializes the
same V7 primes and powers, and returns failure when an input table cannot
be opened.  The header change only makes that shared helper valid C99.

`cmd/deroff.c` remains byte-identical to the V7 source:

```
diff -u v7/usr/src/cmd/deroff.c cmd/deroff.c
```

produced no output.

The installed `/bin/spell` is staged from `cmd/spell/spell.sh`.  The
current script keeps the V7 data flow but replaces the historical
pipe-only chain with temporary files because this port's shell/pipe
behavior is still fidelity-sensitive:

```
--- v7/bin/spell
+++ cmd/spell/spell.sh
@@
-deroff -w $F |\
-  sort -u |\
-  /usr/lib/spell ${S-/usr/dict/hstop} $T |\
-  /usr/lib/spell ${D-/usr/dict/hlista} $V $B |\
-  sort -u +0f +0 - $T |\
+deroff -w $F > ${T}w
+sort -u ${T}w > ${T}u
+/usr/lib/spell ${S-/usr/dict/hstop} $T < ${T}u > ${T}s
+/usr/lib/spell ${D-/usr/dict/hlista} $V $B < ${T}s > ${T}o
+sort -u +0f +0 ${T}o $T |\
   tee -a $H
```

The dictionary payloads are copied directly from the V7 tree.  A forced
GNU make rebuild exposed that `root/usr/dict/spellhist` and
`root/usr/dict/words` can inherit owner-nonwritable V7 modes in the host
staging tree, so a later `make -B` plain `cp` can fail before mkfs runs.
The Makefile now removes each old staged dictionary target before
copying it again.  This changes only repeatability of host staging; the
runtime image modes still come from `conf/qemu_arm/root.proto`
(`/usr/dict/spellhist` is `666`, the others are `644`).

Host checksum evidence after the forced rebuild:

```
1409855690 196513 root/usr/dict/words
3022744057 50000 root/usr/dict/hlista
1195046640 50000 root/usr/dict/hlistb
2178767393 50000 root/usr/dict/hstop
4294967295 0 root/usr/dict/spellhist
1409855690 196513 v7/usr/dict/words
3022744057 50000 v7/usr/dict/hlista
1195046640 50000 v7/usr/dict/hlistb
2178767393 50000 v7/usr/dict/hstop
4294967295 0 v7/usr/dict/spellhist
```

Build and QEMU evidence are in `logs/unix-on-qemu.md` under
`V7_SPELL_DEROFF`.

Install wiring for the spell slice is explicit in the build:

* top-level `Makefile` includes `root/bin/spell`, `root/bin/deroff`,
  `root/usr/lib/spell`, `root/usr/lib/spellin`,
  `root/usr/lib/spellout`, `root/usr/dict/words`,
  `root/usr/dict/hlista`, `root/usr/dict/hlistb`,
  `root/usr/dict/hstop`, and `root/usr/dict/spellhist` in the root
  image prerequisites; it stages `/bin/spell` from
  `cmd/spell/spell.sh` and copies every `/usr/dict/*` payload from the
  V7 tree.
* `lib/Makefile` builds `cmd/deroff.c` into `root/bin/deroff` and builds
  `cmd/spell/spell.c`, `spellin.c`, and `spellout.c` into
  `root/usr/lib/spell`, `root/usr/lib/spellin`, and
  `root/usr/lib/spellout`.
* `conf/qemu_arm/root.proto` installs `/bin/spell`, `/bin/deroff`, the
  three `/usr/lib/spell*` helpers, and `/usr/dict/words`,
  `/usr/dict/hlista`, `/usr/dict/hlistb`, `/usr/dict/hstop`, and
  writable `/usr/dict/spellhist` into the QEMU root filesystem.

#### `spell -b` option parsing with file operands

Enemy found a runtime-only script regression after the temporary-file
rewrite: `spell -b file` and `spell file -b` passed `-b` through to
`deroff`, yielding `Deroff: Invalid flag b` or `Deroff: Cannot open file
-b`.  `spell -b <file` still worked because no file operand was present.

The fix keeps V7 spell semantics but avoids this port's fragile `for A
in $*` behavior by scanning arguments with `while`/`shift`:

```
while :
do
	case $# in
	0)	break ;;
	esac
	case $1 in
	-v)	B="$B -v"
		V=${T}a ;;
	-a)	;;
	-b) 	D=${D-/usr/dict/hlistb}
		B="$B -b" ;;
	*)	F="$F $1"
	esac
	shift
done
```

Only non-option operands are appended to `F`, so `deroff -w $F` never
sees `-b`.  The British option still selects `/usr/dict/hlistb` and
passes `-b` to the second `/usr/lib/spell` stage, matching the original
V7 script's option effect.  The staged temp-file pipeline now includes
the original V7 `sort -u` prefilter as its own temporary step:

```
deroff -w $F > ${T}w
sort -u ${T}w > ${T}u
/usr/lib/spell ${S-/usr/dict/hstop} $T < ${T}u > ${T}s
/usr/lib/spell ${D-/usr/dict/hlista} $V $B < ${T}s > ${T}o
sort -u +0f +0 ${T}o $T |\
  tee -a $H
```

QEMU evidence is in `logs/unix-on-qemu.md` under
`V7_SPELL_B_OPTION_FILE_ARGS`: `spell -b /tmp/roff.in`, `spell
/tmp/roff.in -b`, and `spell -b </tmp/roff.in` all report only the
nonexistent words from marked-up input; `colour` is accepted under `-b`.

Additional create/write checks:

```
/bin/echo external > direct.out; echo EXT_DIRECT_STATUS:$?; cat direct.out
EXT_DIRECT_STATUS:0
external
# /bin/echo first > append.out; /bin/echo second >> append.out; echo EXT_APPEND_STATUS:$?; cat append.out
EXT_APPEND_STATUS:0
first
second
# touch touch.out; echo TOUCH_STATUS:$?; ls -l touch.out
TOUCH_STATUS:0
-rw-rw-r-- 1 root        0 Dec 31 19:00 touch.out
```

Small regression set:

```
sed: echo abc | sed 's/b/B/' -> aBc
awk: echo 'x y' | awk '{print $2 ":" $1}' -> y:x
expr: expr 3 + 4 -> 7; expr 5 \* 6 -> 30
dc: echo '2 3+p' | dc -> 5
factor 84 -> 2, 2, 3, 7
```

`primes 10 20` is not a bounded range test for this port; it starts an
unbounded prime stream at 10, so the combined regression batch timed out
while printing continuing primes.

### redirection truncate-existing follow-up

Verifier reproduced `: > trunc.out` leaving an existing file at size 4
with contents `old`.  The fix keeps the earlier redirection/nohup fd
persistence work and adds the missing truncate-only path:

* `arch/armboot.c`: the reuse-existing branch of `kcreat()` now writes
  the zero-size dinode immediately and refreshes matching v7 in-core
  inode shadows, so a close with no intervening write cannot restore the
  old size/block list.
* `cmd/sh/xec.c`, `cmd/sh/service.c`: the shell's `SYSNULL` (`:`) path
  now applies redirections as no-op opens/creates/truncates, then closes
  those temporary fds without renaming the parent shell's live stdin,
  stdout, or stderr.

QEMU evidence after `make ARCH=arm CONF=qemu_arm`:

```
cd /tmp
# rm -f trunc.out out nohup.out scr
# /bin/echo old > trunc.out
# : > trunc.out
# ls -l trunc.out
-rw-rw-r-- 1 root        0 Dec 31 19:00 trunc.out
# cat trunc.out
# /bin/echo HI > out 2>&1
# cat out
HI
# nohup /bin/echo HI
Sending output to 'nohup.out'
# cat nohup.out
HI
# ./scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

Append regression:

```
/bin/echo first > append.out
# /bin/echo second >> append.out
# cat append.out
first
second
```

### script-level redirection shared-fd follow-up

Enemy found a remaining regression where redirecting a script containing
multiple commands preserved only the last line in the redirected output.
The regression affected both external commands and shell builtins inside
the script.

Fix scope:

* `arch/armboot.c`: after fork/spawn exit restores the parent shell's
  armboot `files[]` snapshot and `u.u_ofile[]`, mirror every restored
  regular-file fd from the shared v7 file/inode state.  This preserves
  the child-advanced offset plus size/block metadata for inherited
  redirected stdout/stderr before the next script command forks.

QEMU evidence after `make ARCH=arm CONF=qemu_arm`:

```
cd /tmp
# ./s_ext > ext.out 2>&1
# cat ext.out
ext1
ext2
ext3
# ./s_builtin > builtin.out 2>&1
# cat builtin.out
bi1
bi2
bi3
```

Prior mission checks from the same boot:

```
# : > trunc.out
# ls -l trunc.out
-rw-rw-rw- 1 root        0 Dec 31 19:00 trunc.out
# /bin/echo direct > out 2>&1
# cat out
direct
# /bin/echo first > append.out
# /bin/echo second >> append.out
# cat append.out
first
second
# ls missing-file > err.out 2>&1
# cat err.out
missing-file not found
# nohup /bin/echo HI
Sending output to 'nohup.out'
# cat nohup.out
HI
# ./scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

### V7-routed link/unlink/rmdir metadata follow-up

Enemy found two real QEMU regressions after the directory metadata
refresh fix:

* A hard link created by `ln aa/file aa/linkfile` was destroyed when the
  original name was removed; `aa/linkfile` became a zero-mode,
  zero-size, unreadable inode.
* A nested empty directory failed `rmdir nd/sub`, and the directory
  entry degraded to a zero-mode inode.

Root cause: armboot's local dinode writeback path still treated its
small `struct file` snapshot as authoritative for all inode metadata.
`putino()` rewrote the whole dinode and hard-coded `di_nlink = 1`.
That is only valid when armboot allocates a brand-new inode; it is
wrong after V7-routed `link()` has raised a regular file's link count,
and it is especially wrong for directories whose `.` / `..` / parent
entry link counts are managed by V7 `unlink()` during historical
`rmdir`.

Fix scope:

* `arch/armboot.c::putino()` now preserves existing dinode metadata
  that V7 owns, including `di_nlink`, uid/gid, and timestamps.  It still
  writes the mode, size, and packed block addresses that armboot owns
  for regular-file byte I/O.  A never-before-used dinode still receives
  initial `di_nlink = 1`.
* `arch/armboot.c::kclose()` no longer writes directory dinodes on
  close.  Open/read/close of a directory is not a metadata mutation, and
  V7-routed `link()` / `unlink()` / `rmdir` own directory link-count
  changes through the buffer cache.

This keeps the V7 source semantics intact: `sys/sys2.c::link()` bumps
`ip->i_nlink`, `sys/sys4.c::unlink()` decrements it and lets `iput()`
truncate/free only when the count reaches zero, and historical
`cmd/rmdir.c` still removes `name/..`, `name/.`, then `name` using
`unlink(2)`.

QEMU evidence is in `logs/unix-on-qemu.md` under
`V7-routed link/unlink/rmdir metadata follow-up`.

### tar.c

Original at `v7/usr/src/cmd/tar/tar.c`.  The port lands as
`cmd/tar/tar.c` and installs as `/bin/tar`.

The archive format and command behavior are the V7 implementation:
512-byte tar blocks, V7 header fields, recursive directory descent
through `struct direct`, hard-link table handling, `c/r/u/t/x` option
flow, `-f -` stdin/stdout archive support, blocked-tape detection, and
update/append code paths are retained.

Concrete source comparison against V7 shows the delta is limited to C99
and ARM build requirements:

* Added typed prototypes for `sprintf`, `strcat`, and tar's file-scope
  functions so the strict C99 target build does not rely on implicit
  declarations.
* Added explicit `int` return types to K&R function definitions and
  explicit missing parameter declarations for `checkw`, `done`,
  `bsrch`, and `cmp`.
* Added `return(0)` to functions that historically fell off the end,
  preserving the V7 integer-return calling convention while satisfying
  C99 diagnostics.
* Made implicit `register` locals explicit as `register int`.
* Cast `signal()` handler arguments and `SIG_IGN` through `int`, matching
  this port's libc signal ABI.
* Cast buffered tape I/O through `char *` when passing the `union hblock`
  tape buffer to `read`, `write`, and `copy`.

Representative source delta:

```diff
@@
-char	*sprintf();
-char	*strcat();
+char	*sprintf(char *buf, char *fmt, ...);
+char	*strcat(char *a, char *b);
 daddr_t	bsrch();
+int	usage(), done(), dorep(), doxtract(), dotable(), getdir(),
+	passtape(), endtape(), getwdir(), putfile(), putempty(),
+	flushtape(), readtape(), writetape(), backtape(), longt(),
+	pmode(), select(), checkdir(), onintr(), onquit(), onhup(),
+	onterm(), tomodes(), checksum(), checkw(), response(),
+	checkupdate(), prefix(), cmp(), copy();
@@
+int
 main(argc, argv)
 int	argc;
 char	*argv[];
@@
-		if (signal(SIGINT, SIG_IGN) != SIG_IGN)
-			signal(SIGINT, onintr);
+		if (signal(SIGINT, (int)SIG_IGN) != (int)SIG_IGN)
+			signal(SIGINT, (int)onintr);
@@
-	register i;
+	register int i;
@@
-		if ((i = read(mt, tbuf, TBLOCK*j)) < 0) {
+		if ((i = read(mt, (char *)tbuf, TBLOCK*j)) < 0) {
@@
-	copy(&tbuf[recno++], buffer);
+	copy((char *)&tbuf[recno++], buffer);
```

Build/install wiring:

* `lib/Makefile` already builds `cmd/tar/tar.c` as a one-off target and
  installs the flat binary at `root/bin/tar`; this slice added
  `../root/bin/tar` to `lib/Makefile clean`.
* Top-level `Makefile` now lists `cmd/tar/*` in the `root.img`
  prerequisites so a tar source edit forces the root filesystem image to
  rebuild.
* `conf/qemu_arm/root.proto` already includes `tar ---755 0 0
  root/bin/tar`, so no root prototype change was needed.

Build and QEMU evidence are in `logs/unix-on-qemu.md` under
`tar(1) V7 port coverage`.

### tp(1)

Original sources are `v7/usr/src/cmd/tp/tp0.c`, `tp1.c`, `tp2.c`,
`tp3.c`, and `tp.h`; the historical initialized data header is
`v7/usr/include/tp_defs.h`.  The port lands as `cmd/tp/tp0.c`,
`cmd/tp/tp1.c`, `cmd/tp/tp2.c`, `cmd/tp/tp3.c`, `cmd/tp/tp.h`, and
`cmd/tp/tp_defs.h`, and installs as `/bin/tp`.

Inventory entry: `cmd/tp/*` is built by `lib/Makefile` into
`root/bin/tp`, top-level `Makefile` includes `root/bin/tp` in `ROOT`,
`root.img` now depends on `cmd/tp/*`, and
`conf/qemu_arm/root.proto` installs `tp ---755 0 0 root/bin/tp`.
`lib/Makefile clean` now removes `../root/bin/tp`.

Archive format and command behavior are the V7 implementation: the
512-byte `struct tent` directory blocks, magtape/dectape option flow,
directory checksum/swab handling, pathname packing, block bitmap
allocator, table/extract/delete/update command selection, and
interactive `v`/`w` verification behavior are retained.

Per-file comparison notes:

* `tp0.c`: unchanged from V7.  It still includes `tp.h` and
  `<tp_defs.h>`.
* `tp.h`: unchanged from V7.  The historical archive constants,
  `struct tent`, in-core `struct dent`, global commons, and flag values
  are retained.
* `tp_defs.h`: copied unchanged from `v7/usr/include/tp_defs.h` into
  the local `cmd/tp` include directory so the target build can resolve
  the historical `<tp_defs.h>` include without depending on a staged
  system include directory.  The default `/dev/mt0`, `/dev/tapx`,
  `/usr/mdec/mboot`, `/usr/mdec/tboot`, and initial `flags = flu`
  definitions are byte-for-byte historical.
* `tp1.c`: adds `stdio.h`, file-scope prototypes, explicit `int`
  return types, an explicit `argc` declaration, `(void)argc`, explicit
  `register int n`, and `return(0)` on historical fall-through paths.
* `tp2.c`: adds file-scope prototypes, explicit `int` return types and
  parameter declarations, explicit integer locals, casts around
  `sizeof(...)` loop bounds, and `return(0)` on historical fall-through
  paths.
* `tp3.c`: adds `stdio.h`, file-scope prototypes, explicit `int`
  return types and locals, the `localtime()` result cast used by this
  port's libc headers, an unsigned comparison cast in `setmap()`, and
  `return(0)` on historical fall-through paths.

Representative source deltas:

```diff
--- v7/usr/src/cmd/tp/tp1.c
+++ cmd/tp/tp1.c
@@
 #include "tp.h"
+#include <stdio.h>
 
+int	optap(), setcom(), useerr(), check(), done(), encode(),
+	decode(), cmd(), cmr(), cmt(), cmx(),
+	clrdir(), clrent(), rddir(), gettape(), wrdir(), getfiles(),
+	update(), delete(), taboc(), extract(), usage();
+
+int
 main(argc,argv)
+int argc;
 char **argv;
 {
 	register char c,*ptr;
-	extern cmd(), cmr(),cmx(), cmt();
+	extern int cmd(), cmr(),cmx(), cmt();
+	(void)argc;
@@
 	(*command)();
+	return(0);
 }
@@
-	register n;
+	register int n;
```

```diff
--- v7/usr/src/cmd/tp/tp2.c
+++ cmd/tp/tp2.c
@@
 #include <sys/dir.h>
 
+int	rseek(), wseek(), tread(), twrite(), seekerr(), swabdir(),
+	encode(), decode(), done(), bitmap(), fserr(), callout(),
+	expand(), clrent();
@@
+int
 clrdir()
 {
-	register j, *p;
+	register int j, *p;
@@
-		for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+		for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@
 rseek(blk)
+int blk;
```

```diff
--- v7/usr/src/cmd/tp/tp3.c
+++ cmd/tp/tp3.c
@@
 #include "tp.h"
+#include <stdio.h>
 
+int	decode(), verify(), clrent(), bitmap(), maperr(), setmap(),
+	wrdir(), update1(), wseek(), twrite(), phserr(), done(),
+	rseek(), tread(), usage();
@@
-	register b, last;
+	register int b, last;
@@
-	if ((c += block) >= tapsiz)		maperr();
+	if ((c += block) >= (unsigned)tapsiz)		maperr();
@@
-		m = localtime(&dd->d_time);
+		m = (int *)localtime(&dd->d_time);
```

Non-V7 deltas are limited to C99/Armv7/build fixes: prototypes and
explicit returns for strict C99, explicit local types for K&R implicit
`int`, `stdio.h` for `printf()`/`getchar()`, casts for libc/header ABI
and warning fixes, the local include workaround for `tp_defs.h`, and
build/rootfs wiring.

Build and QEMU evidence are in `logs/unix-on-qemu.md` under
`tp(1) V7 port coverage`.

## update(8) V7 userspace slice attempt

Inventory:

* `cmd/update.c` ports historical `v7/usr/src/cmd/update.c` and is built
  by `lib/Makefile` in the `ETC` loop, landing at `root/etc/update`.
  The top-level `ROOT` list already includes `root/etc/update`, and
  `conf/qemu_arm/root.proto` installs it as `/etc/update` with mode 755.

Per-file comparison notes:

* `cmd/update.c`: retains the V7 daemon body: fork and parent exit, child
  closes fds 0/1/2, opens `/bin`, `/usr`, and `/usr/bin` for directory
  cache benefit, calls `sync()`, arms `SIGALRM`, and loops in `pause()`.
  C99 deltas are limited to `stdio.h` for the local libc prototypes,
  explicit `int` return types, explicit `void` parameter lists, and the
  existing `(int)dosync` signal ABI cast used by this Armv7 port.
* `lib/Makefile`: `update` was already in `ETC`; `clean` now removes
  `../root/etc/update` so the built rootfs artifact does not survive a
  clean.

Representative source delta:

```diff
--- v7/usr/src/cmd/update.c
+++ cmd/update.c
@@
-#include <signal.h>
+#include <stdio.h>
+#include <signal.h>
+
+int	dosync(void);
@@
-main()
+int
+main(void)
@@
-dosync()
+int
+dosync(void)
 {
 	sync();
-	signal(SIGALRM, dosync);
+	signal(SIGALRM, (int)dosync);
 	alarm(30);
+	return(0);
 }
```

Runtime note: the source-level behavior remains the V7 daemon pattern
above.  Direct QEMU testing exposed an Armv7 port limitation in the
daemon path: the port's fork model normally runs the child until exit,
and the old pause bridge spun in `pause_spin_barrier()` (writing
backspace characters on each iteration).  A detached daemon child such
as `update` therefore reached `pause()` and kept the shell from
resuming.

Narrow runtime shim fix:

* `arch/armboot.c`: `sys_pause_v7()` now recognizes the historically
  normal daemon case where the current process is a fork child and fds
  0/1/2 have all been detached from `/dev/console`.  Instead of entering
  the foreground pause spin loop, it marks the child paused, restores
  the saved parent fork frame/state, frees the parent save slot, and
  returns the daemon pid to the parent's `fork()` call.  The parent then
  follows V7 `update`'s `if(fork()) exit(0)` path, so the invoking shell
  sees status 0 and remains usable.
* `arch/u_bridge.c`: adds `v7_proc_pause_current()` so the parked
  daemon remains visible in the V7 `proc[]` table as a sleeping process
  for `ps`.

Foreground pauses, including libc `sleep(n)`, still use the existing
`v7_pause_call()` / `pause_spin_barrier()` path so the clock IRQ keeps
advancing under QEMU.
That scheduler/pause behavior is outside this userspace slice and was
not broadened here.

## at(1) / atrun(8) V7 userspace slice

Inventory:

* `cmd/at.c` ports historical `v7/usr/src/cmd/at.c` and is built by
  `lib/Makefile` in the normal `BIN` loop, landing at `root/bin/at`.
* `cmd/atrun.c` ports historical `v7/usr/src/cmd/atrun.c` and is built
  by `lib/Makefile` in the normal `ETC` loop, landing at
  `root/etc/atrun`.
* `conf/qemu_arm/root.proto` installs `/bin/at`, `/etc/atrun`, and the
  historical spool layout `/usr/spool/at`, `/usr/spool/at/past`, and
  `/usr/spool/at/lasttimedone`.

Per-file comparison notes:

* `cmd/at.c`: retains the V7 parser and file naming scheme:
  `YY.YYY.HHMM.UU` names under `/usr/spool/at`, month/weekday parsing,
  `week`, AM/PM/noon/midnight handling, stdin-or-file job body copy,
  cwd prelude, environment prelude, and SIGINT cleanup.  C99 deltas are
  explicit return types/prototypes and signal casts.  Arm runtime deltas
  are narrow: `popen("pwd")` is replaced by a local pipe/fork/exec of
  `/bin/pwd` to avoid this shell port's broken `sh -c` path; the result
  is trimmed to one line; missing job files are created with `creat()`
  before retrying `fopen("a")` because this libc's `open()` wrapper does
  not maintain `errno` for stdio append-create; and only environment
  entries containing `=` are written because this shell/runtime can leak
  the command operand into `environ`.
* `cmd/atrun.c`: retains V7 due-job scanning, timestamp comparison,
  child-per-job execution, `lasttimedone` update, move into `past`, uid/gid
  handoff, nice value, and post-run unlink.  C99 deltas are explicit
  return types/prototypes.  Arm runtime deltas avoid two shell-port
  incompatibilities: `/bin/mv file past` is executed directly through
  fork/exec instead of `system("/bin/mv ...")`, and the job file is opened
  on fd 0 before `execl("/bin/sh", "sh", 0)` because this Bourne shell
  port rejects script filenames as argv.  The historical observable
  batch behavior remains: the queued file is moved to `past`, run by
  `/bin/sh`, then unlinked after the shell exits.
* `conf/qemu_arm/root.proto`: adds only the spool subtree needed by
  `at`/`atrun`: `/usr/spool` mode 755, `/usr/spool/at` mode 777,
  `/usr/spool/at/past` mode 777, and writable seed file
  `/usr/spool/at/lasttimedone`.  No cron daemon behavior was changed.

Representative source delta:

```diff
--- v7/usr/src/cmd/at.c
+++ cmd/at.c
@@
-FILE	*popen();
+FILE	*openjob();
+int	makeutime(), makeuday(), filename(), onintr(), getpwd();
@@
-	if ((pwfil = popen("pwd", "r")) == NULL) {
+	if (getpwd(pwbuf, sizeof(pwbuf)) < 0) {
 		fprintf(stderr, "at: can't execute pwd\n");
 		exit(1);
 	}
-	fgets(pwbuf, 100, pwfil);
-	pclose(pwfil);
 	fprintf(file, "cd %s", pwbuf);
@@
-			fprintf(file, "%s\n", *ep++);
+			if (index(*ep, '='))
+				fprintf(file, "%s\n", *ep++);
+			else
+				ep++;
```

```diff
--- v7/usr/src/cmd/atrun.c
+++ cmd/atrun.c
@@
-	sprintf(sbuf, "/bin/mv %.14s %s", file, PDIR);
-	system(sbuf);
+	if (movefile(file, PDIR) < 0)
+		exit(1);
@@
-	execl("/bin/sh", "sh", file, 0);
+	close(0);
+	open(file, 0);
+	execl("/bin/sh", "sh", 0);
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`at(1) / atrun(8) V7 port coverage`.

## cron(8) V7 userspace slice

Inventory:

* `cmd/cron.c` ports historical `v7/usr/src/cmd/cron.c` and is built by
  `lib/Makefile` in the `ETC` loop, landing at `root/etc/cron`.
* `Makefile` now stages the historical `v7/usr/lib/crontab` into
  `root/usr/lib/crontab` and makes `root.img` depend on it.
* `conf/qemu_arm/root.proto` installs `root/usr/lib/crontab` as
  `/usr/lib/crontab` mode 644.  The installed file is a byte-for-byte
  copy of the V7 table.

Per-file comparison notes:

* `cmd/cron.c`: retains the V7 crontab path, parser, matching fields,
  minute loop, setuid(1), ignored HUP/INT/QUIT, and shell execution via
  `/bin/sh -c`.  Existing C99 deltas remain prototypes, explicit return
  types, explicit local `int`s, and signal ABI casts.  New Arm runtime
  deltas are limited to daemon execution under the current single-thread
  fork model: fd 1/2 are detached with explicit `close()`/`open("/")`
  calls because this libc `freopen("/", "r", stdout/stderr)` did not
  make the daemon visible as detached to the pause shim; the scheduled
  command path uses one fork instead of V7's double-fork+wait because the
  nested fork/wait path stranded cron before it could reach the daemon
  pause/yield point; and the first current-minute scan is performed
  before an explicit daemon `pause()` so QEMU can verify one scheduled
  shell command and then regain the invoking shell.
* `cmd/sh/name.c`: `getenv()` now ignores environment strings without
  `=`.  This matches the shape of a real Unix environment and avoids this
  port's argv leak making `/bin/sh -c ...` die while importing `-c` as a
  variable name.
* `cmd/sh/main.c`: restored the historical entry flow: option handling
  is again delegated to `options(c, v)` instead of a pre-parser scan.
  This avoids bypassing the shell's normal `-c` argument shuffle.
* `arch/armboot.c`: the flat argv builder now recognizes only the
  no-extra-argv shell form `sh -c command` (including `/bin/sh` and
  combined options containing `c`) and encodes spaces/tabs inside the
  command argument as byte `037` before copying the flat buffer to
  `UARGV`.  This preserves the single command-string boundary through
  the Arm handoff without changing calls that pass additional argv
  words.
* `cmd/sh/args.c`: the historical `-c` parser still recognizes `c`
  inside the option word and assigns `comdiv`.  It decodes `037` back to
  a shell space only when there are no extra argv words after the command
  argument.  If extra words remain, it keeps the port's prior single-word
  `comdiv` behavior instead of folding those words into command text;
  this preserves the existing mission behavior for
  `sh -c 'echo $1 $2' x A B`.  The compatibility delta is still limited
  to the Arm exec handoff, where `execl("/bin/sh", "sh", "-c", s, 0)`
  from cron otherwise loses every word after the first space in `s`;
  `sh < file` and ENOEXEC fallback still use their existing paths.
* `Makefile`: adds only `root/usr/lib/crontab` to the rootfs prerequisite
  list and a copy rule from `v7/usr/lib/crontab`.
* `conf/qemu_arm/root.proto`: adds only the `/usr/lib/crontab` file entry.
* `root/usr/lib/crontab`: historical V7 `/usr/lib/crontab` content:
  dmesg, atrun, and calendar entries.

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`cron(8) V7 port coverage`.

Retry Worker shell `-c` regression fix:

Enemy/Verifier found that the previous retry joined every word after
`-c`, which made the existing VARS mission line
`sh -c 'echo $1 $2' x A B` print folded argv content.  The current fix
does not join split argv tails.  Instead, `arch/armboot.c` preserves the
boundary of only no-extra `sh -c command` invocations with a private
`037` space marker, and `cmd/sh/args.c` decodes that marker only when
there are no extra argv words after the command argument.  Fresh QEMU
evidence showed the VARS line prints a blank line, while
`sh -c 'echo SIMPLE_OK'`,
`/bin/sh -c 'echo SHC_OK>/tmp/shc.mark'`, cron's real `/bin/sh -c`
child path, `sh < file`, and ENOEXEC fallback all still work.

## passwd(1) V7 userspace slice

`cmd/passwd.c` was compared directly with `v7/usr/src/cmd/passwd.c`.
The current port keeps the historical password-file paths
`/etc/passwd` and `/etc/ptmp`, user lookup and permission check,
non-root old-password verification, password-strength retry logic,
two-character salt generation from `time()+getpid()`, `crypt(3)`,
temporary-file rewrite, and final recreate/copy of `/etc/passwd`.

No source change was needed for this slice.  The concrete source delta
against V7 is limited to C99/ARM build shape:

* Removed local `getpwent()` and `endpwent()` declarations because
  `<pwd.h>` supplies the prototypes in this port.
* Added explicit `int main` return type and explicit `int argc` in the
  K&R-style definition.
* Cast `SIG_IGN` to `int` in the three `signal()` calls, matching the
  userland signal ABI used by other C99 ports in this tree.

Retained historical oddities:

* Successful password changes still exit through `bex:` and call
  `exit(1)`.  QEMU verifies `PASSWD_STATUS:1` even though `/etc/passwd`
  was updated.
* The password buffer remains `char pwbuf[10]`, so input is historically
  bounded/truncated by the old interface rather than modernized.
* A missing user and ordinary permission failure both print
  `Permission denied.` and return the same nonzero status.

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`passwd(1) V7 userspace slice`.

Follow-up clean-rule fix:

Enemy found that `lib/Makefile clean` did not remove the staged
`root/bin/passwd` binary.  The only follow-up source change is adding
`../root/bin/passwd` to that clean target; `cmd/passwd.c` behavior is
unchanged.  Fresh evidence in `logs/unix-on-qemu.md` under
`passwd(1) clean-rule follow-up` shows a sentinel `root/bin/passwd` is
removed by `make -C lib clean`, `root.img` is rebuilt and then
up-to-date by `make -q root.img`, and the passwd success, mismatch,
missing-user, grep, sed, awk, sort, and shell QEMU checks still pass.

## random(1) V7 userspace slice

`cmd/random.c` was compared directly with `v7/usr/src/cmd/random.c`.
The port retains the historical random line-filter and random-exit
behavior: numeric fraction parsing with `atof`, `-e` exit-status mode,
`-r` unbuffered flag handling, time-seeded `srand`, `rand()/MAXINT`
selection, stdin `gets(line)` loop, `puts(line)` output, and the final
`exit((int)(rand()/MAXINT*fract))`.

No source change was needed for this slice.  The complete source delta
against V7 is only the C99 entry-point form:

```diff
--- v7/usr/src/cmd/random.c
+++ cmd/random.c
@@
-main(argc,argv) char **argv;
+int
+main(int argc, char **argv)
 {
```

Build and install inventory:

* `lib/Makefile` lists `random` in `BIN` and removes
  `../root/bin/random` in `clean`.
* The top-level `Makefile` has `root/bin/random` in the root image
  prerequisites.
* `conf/qemu_arm/root.proto` installs `random ---755 0 0 root/bin/random`
  as `/bin/random`.
* `test_serv inventory` could not be run in this shell because
  `test_serv` was not on `PATH` (`command not found`).
* `make ARCH=arm CONF=qemu_arm` completed successfully and reported
  `make: Nothing to be done for 'all'.`

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`random(1) V7 userspace slice`.

## dump/restor V7 dump-format tools slice

This slice covers `cmd/dump.c`, `cmd/dumpdir.c`, `cmd/restor.c`, and
`include/dumprestor.h`, compared directly against the V7 originals at
`v7/usr/src/cmd/{dump,dumpdir,restor}.c` and
`v7/usr/include/dumprestor.h`.

### include/dumprestor.h

`cmp -l v7/usr/include/dumprestor.h include/dumprestor.h` produced no
output.  The header is byte-identical to V7: `NTREC`, `MLEN`, `MSIZ`,
the `TS_*` record type numbers, `MAGIC`, `CHECKSUM`, `struct spcl`, and
`struct idates` are unchanged.

### cmd/dump.c

The dump-format writer is the V7 source with C99/ARM declaration fixes
only.  The on-tape record layout, block-size assumptions, bitmap logic,
incremental dump date handling, default tape/disk/ddate paths, tape
volume prompts, and diagnostics are retained.

Concrete source delta against V7:

* Added forward declarations for internal functions and `l3tol()`.
* Added explicit `int` return types and K&R parameter declarations where
  the V7 compiler supplied implicit int.
* Added explicit `return(0)` at exits from functions that are now typed
  `int`.
* Changed implicit locals such as `register i` to `register int i`.
* Added missing K&R parameter declarations for `indir(..., n)`,
  `dmpspc(..., n)`, `bitmap(..., typ)`, and `bread(..., c)`.
* Cast loop bounds involving `NINDIR`, `DIRPB`, and `BSIZE/sizeof(*ip)`
  to `int` where the strict C99 build otherwise warns.

Representative diff:

```diff
+int	pass(), otape(), bread(), spclrec(), bitmap(), bmapest(), CLR(),
+	getitime(), putitime(), est(), indir(), flusht(), taprec();
+int	l3tol();
+int
 main(argc, argv)
+int argc;
 char *argv[];
 {
-	register i;
+	register int i;
@@
+int
 indir(d, fn1, fn2, n)
 daddr_t d;
 int (*fn1)(), (*fn2)();
+int n;
 {
-	register i;
+	register int i;
@@
-		for(i=0; i<NINDIR; i++) {
+		for(i=0; i<(int)NINDIR; i++) {
```

### cmd/dumpdir.c

The dump-directory reader is the V7 source with C99/ARM declaration
fixes only.  It still reads V7 dump headers, builds the temporary
directory table with `mktemp("rstXXXXXX")`, prints dates through
`ctime()`, walks directory entries by inode, and prints historical
`%5d\t%s%-.14s` path listings.

Concrete source delta against V7:

* Added internal function prototypes and explicit `int` return types.
* Added explicit `int argc`, `register int` locals, and K&R parameter
  declarations required by C99.
* Converted implicit returns to `return(0)`.
* Added `(void)n` in `getfile()` because V7 passes the inode but does
  not use it.
* Cast `sizeof(ino_t)` loop bounds to `int`.
* Replaced `null() { ; }` with `int null() { return(0); }`.

Representative diff:

```diff
+int	readhdr(), checkvol(), pass1(), printem(), gethead(), checktype(),
+	readbits(), flsh(), getfile(), putent(), mseek(), getent(), direq(),
+	search(), readtape(), clearbuf(), flsht(), copy(), writec(), readc(),
+	checksum(), putdir(), null();
+int
 main(argc, argv)
+int argc;
 char *argv[];
@@
-	i = 0;
+int	i = 0;
@@
+	(void)n;
 	addrblock = spcl;
@@
-null() { ; }
+int null() { return(0); }
```

### cmd/restor.c

The restore/extract tool is the V7 source with C99/ARM declaration
fixes plus the minimum anonymous-union member spelling needed by this
tree's C99 headers.  Dump parsing, volume prompts, `t`/`x`/`r`/`R`
commands, extraction-by-inode-name behavior, free-list rebuilding, and
temporary directory table behavior are retained.

Concrete source delta against V7:

* Added internal function prototypes, `l3tol()`/`ltol3()` declarations,
  and `daddr_t balloc(), bmap()` declarations.
* Added explicit `int` return types, K&R parameter declarations,
  `register int` locals, and `return(0)` statements.
* Cast `signal()` arguments/return comparisons to this userland's
  integer signal ABI, matching nearby C99 ports.
* Cast the `gets(tbf)` EOF comparison used by the historical `R` path.
* Cast `sizeof(ino_t)` loop bounds to `int`.
* Added `(void)` markers for parameters historically unused after C99
  typing (`rstrfile` size, `rstrskip` buffer/size).
* Changed `fbuf.df_nfree` / `fbuf.df_free` to
  `fbuf.frees.df_nfree` / `fbuf.frees.df_free` because the C99 compiler
  does not expose V7 K&R's anonymous union-member lookup by default.

Representative diff:

```diff
+int	doit(), readhdr(), checkvol(), pass1(), readbits(), gethead(),
+	checktype(), ishead(), readtape(), flsht(), getfile(), psearch(),
+	getdino(), putdino(), itrunc(), clri(), dread(), dwrite(),
+	rstrfile(), rstrskip(), xtrfile(), skip(), checksum(), putent(),
+	putdir(), null(), copy(), clearbuf(), writec(), readc(), mseek(),
+	getent(), direq(), flsh(), bfree(), tloop();
+int	l3tol(), ltol3();
+daddr_t	balloc(), bmap();
@@
-		if (signal(SIGINT, done) == SIG_IGN)
-			signal(SIGINT, SIG_IGN);
+		if (signal(SIGINT, (int)done) == (int)SIG_IGN)
+			signal(SIGINT, (int)SIG_IGN);
@@
-		fbuf.df_nfree = sblock.s_nfree;
+		fbuf.frees.df_nfree = sblock.s_nfree;
 		for(i=0;i<NICFREE;i++)
-			fbuf.df_free[i] = sblock.s_free[i];
+			fbuf.frees.df_free[i] = sblock.s_free[i];
```

### Build/root image notes

`lib/Makefile`, the top-level `Makefile`, and
`conf/qemu_arm/root.proto` already wired `/bin/dump`, `/bin/dumpdir`,
and `/bin/restor` into the normal ARM build and image.  This slice added
`/etc/ddate` as an empty root image file, because historical `dump(1)`
exits if its incremental dump-date file is absent even for a non-updating
`0f` dump.

`conf/qemu_arm/auxfs.proto` now includes `a ---644 0 0 root/etc/passwd`,
matching the existing Makefile comment that auxfs is a tiny filesystem
holding `/a = root/etc/passwd`.  This gives `dumpdir` and `restor x` a
real small-file entry to list and extract while leaving the dump format
unchanged.

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`dump/restor V7 dump-format tools slice`.

### cmd/grep.c

`cmd/grep.c` was already the V7 source with only C99/Armv7 declaration
repairs.  The matcher, option parsing, V7 regular-expression compiler,
line buffering, exit statuses, and output formatting are unchanged; no
source edit was needed for this slice.

Exact source diff against `v7/usr/src/cmd/grep.c`:

```diff
--- v7/usr/src/cmd/grep.c	1979-02-26 11:51:09.000000000 -0800
+++ cmd/grep.c	2026-05-13 08:11:11.686415383 -0700
@@ -56,8 +56,14 @@
 	128
 };
 
-main(argc, argv)
-char **argv;
+void compile(char *astr);
+void execute(char *file);
+int advance(register char *lp, register char *ep);
+void succeed(char *f);
+int ecmp(char *a, char *b, int count);
+void errexit(char *s, char *f);
+int
+main(int argc, char *argv[])
 {
 	while (--argc > 0 && (++argv)[0][0]=='-')
 		switch (argv[0][1]) {
@@ -142,10 +148,10 @@
 	exit(nsucc == 0);
 }
 
-compile(astr)
-char *astr;
+void
+compile(char *astr)
 {
-	register c;
+	register int c;
 	register char *ep, *sp;
 	char *cstart;
 	char *lastep;
@@ -259,11 +265,11 @@
 	errexit("grep: RE error\n", (char *)NULL);
 }
 
-execute(file)
-char *file;
+void
+execute(char *file)
 {
 	register char *p1, *p2;
-	register c;
+	register int c;
 
 	if (file) {
 		if (freopen(file, "r", stdin) == NULL)
@@ -321,8 +327,8 @@
 	}
 }
 
-advance(lp, ep)
-register char *lp, *ep;
+int
+advance(register char *lp, register char *ep)
 {
 	register char *curlp;
 	char c;
@@ -436,8 +442,8 @@
 	}
 }
 
-succeed(f)
-char *f;
+void
+succeed(char *f)
 {
 	long ftell();
 	nsucc = 1;
@@ -461,17 +467,17 @@
 	printf("%s\n", linebuf);
 }
 
-ecmp(a, b, count)
-char	*a, *b;
+int
+ecmp(char *a, char *b, int count)
 {
-	register cc = count;
+	register int cc = count;
 	while(cc--)
 		if(*a++ != *b++)	return(0);
 	return(1);
 }
 
-errexit(s, f)
-char *s, *f;
+void
+errexit(char *s, char *f)
 {
 	fprintf(stderr, s, f);
 	exit(2);
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/grep` is in `ROOT`.
* `lib/Makefile`: `grep` is in the normal `BIN` compile/link/install loop.
* `conf/qemu_arm/root.proto`: `grep ---755 0 0 root/bin/grep`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`grep V7 userspace historical-accuracy slice`.

### icheck V7 userspace historical-accuracy slice

`cmd/icheck.c` was compared with `v7/usr/src/cmd/icheck.c`.  The port
keeps the V7 checker logic and command behavior, with only C99/Armv7
declaration repairs and the existing `struct fblk` union member spelling
required by this tree's headers.  No source edit was needed for this
slice.

Exact source diff against `v7/usr/src/cmd/icheck.c`:

```diff
--- v7/usr/src/cmd/icheck.c	1979-01-10 12:01:37.000000000 -0800
+++ cmd/icheck.c	2026-05-10 07:15:58.906680187 -0700
@@ -40,14 +40,25 @@
 
 long	atol();
 daddr_t	alloc();
+int	check(char *file);
+int	pass1(struct dinode *ip);
+int	chk(daddr_t bno, char *s);
+int	duped(daddr_t bno);
+int	bfree(daddr_t bno);
+int	bread(daddr_t bno, char *buf, int cnt);
+int	bwrite(daddr_t bno, char *buf);
+int	makefree(void);
+int	l3tol(long *lp, char *cp, int n);
 #ifndef STANDALONE
 char	*malloc();
 #endif
 
+int
 main(argc, argv)
+int argc;
 char *argv[];
 {
-	register i;
+	register int i;
 	long n;
 
 	blist[0] = -1;
@@ -98,10 +109,11 @@
 	return(nerror);
 }
 
+int
 check(file)
 char *file;
 {
-	register i, j;
+	register int i, j;
 	ino_t mino;
 	daddr_t d;
 	long n;
@@ -110,7 +122,7 @@
 	if (fi < 0) {
 		printf("cannot open %s\n", file);
 		nerror |= 04;
-		return;
+		return(0);
 	}
 	printf("%s:\n", file);
 	nrfile = 0;
@@ -131,7 +143,7 @@
 	mino = (sblock.s_isize-2) * INOPB;
 	ino = 0;
 	n = (sblock.s_fsize - sblock.s_isize + BITS-1) / BITS;
-	if (n != (unsigned)n) {
+	if (n != (long)(unsigned)n) {
 		printf("Check fsize and isize: %ld, %u\n",
 		   sblock.s_fsize, sblock.s_isize);
 	}
@@ -146,7 +158,7 @@
 		sflg = 0;
 	}
 	if(!dflg)
-	for(i=0; i<(unsigned)n; i++)
+	for(i=0; i<(int)(unsigned)n; i++)
 		bmap[i] = 0;
 	for(i=2;; i+=NI) {
 		if(ino >= mino)
@@ -171,7 +183,7 @@
 		if (bmap)
 			free(bmap);
 #endif
-		return;
+		return(0);
 	}
 	nfree = 0;
 	while(n = alloc()) {
@@ -213,29 +225,31 @@
 			}
 		printf("missing%5ld\n", n);
 	}
+	return(0);
 }
 
+int
 pass1(ip)
 register struct dinode *ip;
 {
 	daddr_t ind1[NINDIR];
 	daddr_t ind2[NINDIR];
 	daddr_t ind3[NINDIR];
-	register i, j;
+	register int i, j;
 	int k, l;
 
 	i = ip->di_mode & IFMT;
 	if(i == 0) {
 		sblock.s_tinode++;
-		return;
+		return(0);
 	}
 	if(i == IFCHR) {
 		ncfile++;
-		return;
+		return(0);
 	}
 	if(i == IFBLK) {
 		nbfile++;
-		return;
+		return(0);
 	}
 	if(i == IFDIR)
 		ndfile++; else
@@ -243,7 +257,7 @@
 		nrfile++;
 	else {
 		printf("bad mode %u\n", ino);
-		return;
+		return(0);
 	}
 	l3tol(iaddr, ip->di_addr, NADDR);
 	for(i=0; i<NADDR; i++) {
@@ -258,7 +272,7 @@
 		if (chk(iaddr[i], "1st indirect"))
 				continue;
 		bread(iaddr[i], (char *)ind1, BSIZE);
-		for(j=0; j<NINDIR; j++) {
+		for(j=0; j<(int)NINDIR; j++) {
 			if(ind1[j] == 0)
 				continue;
 			if(i == NADDR-3) {
@@ -270,7 +284,7 @@
 			if(chk(ind1[j], "2nd indirect"))
 				continue;
 			bread(ind1[j], (char *)ind2, BSIZE);
-			for(k=0; k<NINDIR; k++) {
+			for(k=0; k<(int)NINDIR; k++) {
 				if(ind2[k] == 0)
 					continue;
 				if(i == NADDR-2) {
@@ -282,7 +296,7 @@
 				if(chk(ind2[k], "3rd indirect"))
 					continue;
 				bread(ind2[k], (char *)ind3, BSIZE);
-				for(l=0; l<NINDIR; l++)
+				for(l=0; l<(int)NINDIR; l++)
 					if(ind3[l]) {
 						ndirect++;
 						chk(ind3[l], "data (garg)");
@@ -290,13 +304,15 @@
 			}
 		}
 	}
+	return(0);
 }
 
+int
 chk(bno, s)
 daddr_t bno;
 char *s;
 {
-	register n;
+	register int n;
 
 	if (bno<sblock.s_isize || bno>=sblock.s_fsize) {
 		printf("%ld bad; inode=%u, class=%s\n", bno, ino, s);
@@ -312,11 +328,12 @@
 	return(0);
 }
 
+int
 duped(bno)
 daddr_t bno;
 {
 	daddr_t d;
-	register m, n;
+	register int m, n;
 
 	if(dflg)
 		return(0);
@@ -352,7 +369,7 @@
 		return(bno);
 	if(sblock.s_nfree <= 0) {
 		bread(bno, buf.data, BSIZE);
-		sblock.s_nfree = buf.df_nfree;
+		sblock.s_nfree = buf.fb.df_nfree;
 		if (sblock.s_nfree<0 || sblock.s_nfree>NICFREE) {
 			printf("Bad free list, entry count of block %ld = %d\n",
 				bno, sblock.s_nfree);
@@ -360,11 +377,12 @@
 			return(0);
 		}
 		for(i=0; i<NICFREE; i++)
-			sblock.s_free[i] = buf.df_free[i];
+			sblock.s_free[i] = buf.fb.df_free[i];
 	}
 	return(bno);
 }
 
+int
 bfree(bno)
 daddr_t bno;
 {
@@ -378,21 +396,24 @@
 	if(sblock.s_nfree >= NICFREE) {
 		for(i=0; i<BSIZE; i++)
 			buf.data[i] = 0;
-		buf.df_nfree = sblock.s_nfree;
+		buf.fb.df_nfree = sblock.s_nfree;
 		for(i=0; i<NICFREE; i++)
-			buf.df_free[i] = sblock.s_free[i];
+			buf.fb.df_free[i] = sblock.s_free[i];
 		bwrite(bno, buf.data);
 		sblock.s_nfree = 0;
 	}
 	sblock.s_free[sblock.s_nfree] = bno;
 	sblock.s_nfree++;
+	return(0);
 }
 
+int
 bread(bno, buf, cnt)
 daddr_t bno;
 char *buf;
+int cnt;
 {
-	register i;
+	register int i;
 
 	lseek(fi, bno*BSIZE, 0);
 	if (read(fi, buf, cnt) != cnt) {
@@ -404,8 +425,10 @@
 		for(i=0; i<BSIZE; i++)
 			buf[i] = 0;
 	}
+	return(0);
 }
 
+int
 bwrite(bno, buf)
 daddr_t bno;
 char	*buf;
@@ -414,13 +437,15 @@
 	lseek(fi, bno*BSIZE, 0);
 	if (write(fi, buf, BSIZE) != BSIZE)
 		printf("write error %ld\n", bno);
+	return(0);
 }
 
+int
 makefree()
 {
 	char flg[MAXFN];
 	int adr[MAXFN];
-	register i, j;
+	register int i, j;
 	daddr_t f, d;
 	int m, n;
 
@@ -471,5 +496,5 @@
 #ifndef STANDALONE
 	sync();
 #endif
-	return;
+	return(0);
 }
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/icheck` is in `ROOT`.
* `lib/Makefile`: `icheck` is in the normal `BIN` compile/link/install loop.
* `conf/qemu_arm/root.proto`: `icheck ---755 0 0 root/bin/icheck`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`icheck V7 userspace historical-accuracy slice`.

### ncheck.c

Original at `v7/usr/src/cmd/ncheck.c`.  The port lands as
`cmd/ncheck.c` and installs as `/bin/ncheck`.

Source comparison against the V7 file shows the filesystem traversal,
directory hash table, `-a`, `-i`, and `-s` behavior, diagnostics, and
printed path format remain the historical implementation.  This slice
made no source or build-wiring edits.  The complete source delta is the
minimal C99/Armv7 typing already present in the tree:

```diff
--- v7/usr/src/cmd/ncheck.c	1979-01-10 12:02:02.000000000 -0800
+++ cmd/ncheck.c	2026-05-10 07:15:58.906680187 -0700
@@ -37,11 +37,21 @@
 daddr_t	bmap();
 long	atol();
 struct htab *lookup();
+int	check(char *file);
+int	pass1(struct dinode *ip);
+int	pass2(struct dinode *ip);
+int	pass3(struct dinode *ip);
+int	dotname(struct direct *dp);
+int	pname(int i, int lev);
+int	bread(daddr_t bno, char *buf, int cnt);
+int	l3tol(long *lp, char *cp, int n);
 
+int
 main(argc, argv)
+int argc;
 char *argv[];
 {
-	register i;
+	register int i;
 	long n;
 
 	while (--argc) {
@@ -78,17 +88,18 @@
 	return(nerror);
 }
 
+int
 check(file)
 char *file;
 {
-	register i, j;
+	register int i, j;
 	ino_t mino;
 
 	fi = open(file, 0);
 	if(fi < 0) {
 		fprintf(stderr, "ncheck: cannot open %s\n", file);
 		nerror++;
-		return;
+		return(0);
 	}
 	nhent = 0;
 	printf("%s:\n", file);
@@ -132,36 +143,40 @@
 			pass3(&itab[j]);
 		}
 	}
+	return(0);
 }
 
+int
 pass1(ip)
 register struct dinode *ip;
 {
 	if((ip->di_mode & IFMT) != IFDIR) {
 		if (sflg==0 || nxfile>=NB)
-			return;
+			return(0);
 		if ((ip->di_mode&IFMT)==IFBLK || (ip->di_mode&IFMT)==IFCHR
 		  || ip->di_mode&(ISUID|ISGID))
 			ilist[nxfile++] = ino;
-			return;
+			return(0);
 	}
 	lookup(ino, 1);
+	return(0);
 }
 
+int
 pass2(ip)
 register struct dinode *ip;
 {
 	struct direct dbuf[NDIR];
 	long doff;
 	struct direct *dp;
-	register i, j;
+	register int i, j;
 	int k;
 	struct htab *hp;
 	daddr_t d;
 	ino_t kno;
 
 	if((ip->di_mode&IFMT) != IFDIR)
-		return;
+		return(0);
 	l3tol(iaddr, ip->di_addr, NADDR);
 	doff = 0;
 	for(i=0;; i++) {
@@ -171,7 +186,7 @@
 		if(d == 0)
 			break;
 		bread(d, (char *)dbuf, sizeof(dbuf));
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
 			if(doff >= ip->di_size)
 				break;
 			doff += sizeof(struct direct);
@@ -189,21 +204,23 @@
 				hp->h_name[k] = dp->d_name[k];
 		}
 	}
+	return(0);
 }
 
+int
 pass3(ip)
 register struct dinode *ip;
 {
 	struct direct dbuf[NDIR];
 	long doff;
 	struct direct *dp;
-	register i, j;
+	register int i, j;
 	int k;
 	daddr_t d;
 	ino_t kno;
 
 	if((ip->di_mode&IFMT) != IFDIR)
-		return;
+		return(0);
 	l3tol(iaddr, ip->di_addr, NADDR);
 	doff = 0;
 	for(i=0;; i++) {
@@ -213,7 +230,7 @@
 		if(d == 0)
 			break;
 		bread(d, (char *)dbuf, sizeof(dbuf));
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
 			if(doff >= ip->di_size)
 				break;
 			doff += sizeof(struct direct);
@@ -238,8 +255,10 @@
 			printf("\n");
 		}
 	}
+	return(0);
 }
 
+int
 dotname(dp)
 register struct direct *dp;
 {
@@ -250,28 +269,32 @@
 	return(0);
 }
 
+int
 pname(i, lev)
-ino_t i;
+int i;
+int lev;
 {
 	register struct htab *hp;
 
 	if (i==ROOTINO)
-		return;
+		return(0);
 	if ((hp = lookup(i, 0)) == 0) {
 		printf("???");
-		return;
+		return(0);
 	}
 	if (lev > 10) {
 		printf("...");
-		return;
+		return(0);
 	}
 	pname(hp->h_pino, ++lev);
 	printf("/%.14s", hp->h_name);
+	return(0);
 }
 
 struct htab *
 lookup(i, ef)
 ino_t i;
+int ef;
 {
 	register struct htab *hp;
 
@@ -291,11 +314,13 @@
 	return(hp);
 }
 
+int
 bread(bno, buf, cnt)
 daddr_t bno;
 char *buf;
+int cnt;
 {
-	register i;
+	register int i;
 
 	lseek(fi, bno*BSIZE, 0);
 	if (read(fi, buf, cnt) != cnt) {
@@ -303,17 +328,19 @@
 		for(i=0; i<BSIZE; i++)
 			buf[i] = 0;
 	}
+	return(0);
 }
 
 daddr_t
 bmap(i)
+int i;
 {
 	daddr_t ibuf[NINDIR];
 
 	if(i < NADDR-3)
 		return(iaddr[i]);
 	i -= NADDR-3;
-	if(i > NINDIR) {
+	if(i > (int)NINDIR) {
 		fprintf(stderr, "ncheck: %u - huge directory\n", ino);
 		return((daddr_t)0);
 	}
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/ncheck` is in `ROOT`.
* `lib/Makefile`: `ncheck` is in the normal `BIN` compile/link/install loop and clean removes `../root/bin/ncheck`.
* `conf/qemu_arm/root.proto`: `ncheck ---755 0 0 root/bin/ncheck`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`ncheck V7 userspace historical-accuracy slice`.
### cb V7 userspace historical-accuracy slice

`cmd/cb.c` was compared against `v7/usr/src/cmd/cb.c`.  The current
port is limited to C99/Armv7 compatibility changes: explicit prototypes,
`int` return types/returns for formerly implicit-int functions, unused
`main` argument suppression, and local `puts`/`gets` renames to avoid
host C library header conflicts.  No source changes were needed.

Exact source diff:

```diff
--- v7/usr/src/cmd/cb.c	1979-01-19 13:11:56.000000000 -0800
+++ cmd/cb.c	2026-05-10 07:15:58.902680164 -0700
@@ -1,4 +1,14 @@
 #include <stdio.h>
+#define	puts	cb_puts
+#define	gets	cb_gets
+int	getch(void);
+int	lookup(char **tab);
+int	gotelse(void);
+int	getnl(void);
+int	ptabs(void);
+int	comment(void);
+int	puts(void);
+int	gets(void);
 int	slevel[10];
 int	clevel	= 0;
 int	spflg[20][10];
@@ -36,9 +46,12 @@
 int	tabs	= 0;
 int	lastchar;
 int	c;
+int
 main(argc,argv) int argc;
 char argv[];
 {
+	(void)argc;
+	(void)argv;
 	while((c = getch()) != EOF){
 		switch(c){
 		case ' ':
@@ -257,17 +270,22 @@
 			if(c != ',')lchar = c;
 		}
 	}
+	return(0);
 }
+int
 ptabs(){
 	int i;
 	for(i=0; i < tabs; i++)printf("\t");
+	return(0);
 }
+int
 getch(){
 	if(peek < 0 && lastchar != ' ' && lastchar != '\t')pchar = lastchar;
 	lastchar = (peek<0) ? getc(stdin):peek;
 	peek = -1;
 	return(lastchar);
 }
+int
 puts(){
 	if(j > 0){
 		if(sflg != 0){
@@ -288,7 +306,9 @@
 			aflg = 0;
 		}
 	}
+	return(0);
 }
+int
 lookup(tab)
 char *tab[];
 {
@@ -304,6 +324,7 @@
 	}
 	return(0);
 }
+int
 gets(){
 	char ch;
 beg:
@@ -322,12 +343,15 @@
 	}
 	else return(ch);
 }
+int
 gotelse(){
 	tabs = stabs[clevel][iflev];
 	pflg[level] = spflg[clevel][iflev];
 	ind[level] = sind[clevel][iflev];
 	ifflg = 1;
+	return(0);
 }
+int
 getnl(){
 	while((peek = getch()) == '\t' || peek == ' '){
 		string[j++] = peek;
@@ -349,6 +373,7 @@
 	}
 	return(0);
 }
+int
 comment(){
 rep:
 	while((c = string[j++] = getch()) != '*')
@@ -361,4 +386,5 @@
 		if(c == '*')goto gotstar;
 		goto rep;
 	}
+	return(0);
 }
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/cb` is in `ROOT`.
* `lib/Makefile`: `cb` is in the normal `BIN` compile/link/install loop
  and clean removes `../root/bin/cb`.
* `conf/qemu_arm/root.proto`: `cb ---755 0 0 root/bin/cb`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`cb V7 userspace historical-accuracy slice`.

### sp.c

Original at `v7/usr/src/cmd/sp.c`.  The port lands as `cmd/sp.c` and
installs as `/bin/sp`.

The checked-in source was compared with the V7 original and left
untouched.  The only source delta is the minimal C99/Armv7 compatibility
surface: prototypes, explicit `int` return types, typed locals, and
explicit zero returns for helper functions whose historical callers
ignore the value.  The line packing logic and option handling are
unchanged:

```diff
--- v7/usr/src/cmd/sp.c	1979-01-10 12:02:18.000000000 -0800
+++ cmd/sp.c	2026-05-10 07:15:58.914680234 -0700
@@ -8,9 +8,13 @@
 int alen;	/*actual length*/
 int elen;	/*length on current line*/
 char buf[256];
+int	getit(void);
+int	putit(int ntab);
+int	clean(void);
+int
 getit()
 {	register int i;
-	register c;
+	register int c;
 	slen=alen=elen=0;
 	for(i=0;;i++)
 	{	buf[i]=c=getchar();
@@ -31,16 +35,23 @@
 		}
 	}
 }
+int
 putit(ntab)
+int ntab;
 {	register int i;
 	for(i=0;i<ntab;i++) putchar('\t');
 	for(i=0;i<alen;i++) putchar(buf[i]);
+	return(0);
 }
+int
 clean()
 {
 	putchar('\n');
+	return(0);
 }
+int
 main(argc,argv) char *argv[];
+int argc;
 {	int len,ntab;
 	int i;
 	len=80;
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/sp` is in `ROOT`, and `root.img`
  depends on `cmd/*.c`.
* `lib/Makefile`: `sp` is in the normal `BIN` compile/link/install loop
  and clean removes `../root/bin/sp`.
* `conf/qemu_arm/root.proto`: `sp ---755 0 0 root/bin/sp`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`sp V7 userspace historical-accuracy slice`.

### split.c

Original at `v7/usr/src/cmd/split.c`.  The port lands as `cmd/split.c`
and installs as `/bin/split`.

The checked-in source was compared with the V7 original and left
untouched.  The only source delta is the minimal C99/Armv7 compatibility
surface: prototypes for undeclared libc calls, an explicit `int` return
for `main`, an explicit `argc` declaration, typed register locals, and
an unsigned loop-bound cast for the `unsigned count` comparison.  The V7
option parser, default line count/prefix, stdin `-` handling, two-letter
suffix generation, and output-file loop are unchanged:

```diff
--- v7/usr/src/cmd/split.c	1979-01-10 12:02:19.000000000 -0800
+++ cmd/split.c	2026-05-13 08:47:09.899166473 -0700
@@ -8,10 +8,14 @@
 FILE	*is;
 FILE	*os;
 
+int atoi(char *s);
+void exit(int n);
+int
 main(argc, argv)
+int argc;
 char *argv[];
 {
-	register i, c, f;
+	register int i, c, f;
 	int iflg = 0;
 
 	for(i=1; i<argc; i++)
@@ -53,7 +57,7 @@
 
 loop:
 	f = 1;
-	for(i=0; i<count; i++)
+	for(i=0; (unsigned)i<count; i++)
 	do {
 		c = getc(is);
 		if(c == EOF) {
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/split` is in `ROOT`, and `root.img`
  depends on `cmd/*.c`.
* `lib/Makefile`: `split` is in the normal `BIN` compile/link/install
  loop and clean removes `../root/bin/split`.
* `conf/qemu_arm/root.proto`: `split ---755 0 0 root/bin/split`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`split V7 userspace historical-accuracy slice`.

## stty V7 userspace historical-accuracy slice

Original at `v7/usr/src/cmd/stty.c`.  The port lands as `cmd/stty.c`
and installs as `/bin/stty`.

The checked-in source was compared with the V7 original and left
untouched.  The only source delta is the minimal C99/Armv7 compatibility
surface: prototypes for later functions, an explicit `int` return for
`main`/`eq`, typed function signatures, and a typed `register int` local
in `prmodes`.  The V7 option tables, parser behavior, mode text, and
`stty(1)` output formatting are unchanged:

```diff
--- v7/usr/src/cmd/stty.c	1979-01-10 12:02:20.000000000 -0800
+++ cmd/stty.c	2026-05-10 07:15:58.914680234 -0700
@@ -176,9 +176,13 @@
 
 char	*arg;
 struct sgttyb mode;
+int	eq(char *string);
+void	prmodes(void);
+void	delay(int m, char *s);
+void	prspeed(char *c, int s);
 
-main(argc, argv)
-char	*argv[];
+int
+main(int argc, char *argv[])
 {
 	int i;
 
@@ -229,8 +233,8 @@
 	stty(1,&mode);
 }
 
-eq(string)
-char *string;
+int
+eq(char *string)
 {
 	int i;
 
@@ -246,9 +250,10 @@
 	return(1);
 }
 
-prmodes()
+void
+prmodes(void)
 {
-	register m;
+	register int m;
 
 	if(mode.sg_ispeed != mode.sg_ospeed) {
 		prspeed("input speed  ", mode.sg_ispeed);
@@ -281,8 +286,8 @@
 	fprintf(stderr,"\n");
 }
 
-delay(m, s)
-char *s;
+void
+delay(int m, char *s)
 {
 
 	if(m)
@@ -293,8 +298,8 @@
 	0,50,75,110,134,150,200,300,600,1200,1800,2400,4800,9600,0,0
 };
 
-prspeed(c, s)
-char *c;
+void
+prspeed(char *c, int s)
 {
 
 	fprintf(stderr,"%s%d baud\n", c, speed[s]);
```

Build/root image wiring was already present and unchanged:

* top-level `Makefile`: `root/bin/stty` is in `ROOT`, and `root.img`
  depends on `cmd/*.c`.
* `lib/Makefile`: `stty` is in the normal `BIN` compile/link/install
  loop and clean removes `../root/bin/stty`.
* `conf/qemu_arm/root.proto`: `stty ---755 0 0 root/bin/stty`.

QEMU evidence required more than the prior harmless libc stub:
independent `/bin/stty` invocations must share terminal mode state.
The allowed emulator/compat change is therefore a narrow V7 `sgttyb`
console shim only.  It does not add modern termios, general ioctl
handling, or non-console tty work.

Relevant `lib/compat.c` delta:

```diff
- *   - alarm/pause/ioctl/gtty/stty/nice/getpid stub to harmless values
- *     because the arch/armboot.c trap() handler doesn't service them.
+ *   - ioctl/nice/getpid stay stubbed for now.
+#define	S_STTY		31
+#define	S_GTTY		32
 int
 gtty(int fd, char *buf)
 {
 
-	(void)fd; (void)buf;
-	return(0);
+	return(syscall3(S_GTTY, fd, (int)buf, 0));
 }
@@
 stty(int fd, char *buf)
 {
 
-	(void)fd; (void)buf;
-	return(0);
+	return(syscall3(S_STTY, fd, (int)buf, 0));
 }
```

Relevant `arch/armboot.c` delta:

```diff
+#define	B9600			13
+#define	ECHO			010
+#define	CRMOD			020
+#define	ODDP			0100
+#define	EVENP			0200
+#define	XTABS			06000
+struct sgttyb {
+	char	sg_ispeed;
+	char	sg_ospeed;
+	char	sg_erase;
+	char	sg_kill;
+	int	sg_flags;
+};
+static struct sgttyb console_sgtty = {
+	B9600, B9600, '#', '@', EVENP|ODDP|ECHO|CRMOD|XTABS
+};
+static int
+is_tty_fd(int fd)
+{
+
+	if(fd < 0 || fd >= NFD)
+		return(0);
+	if(fd <= 2 && files[fd].ino == 0)
+		return(1);
+	if(files[fd].ino == 0)
+		return(0);
+	if((files[fd].mode & IFMT) != IFCHR)
+		return(0);
+	if(files[fd].pipe != 0 || files[fd].kmem != 0)
+		return(0);
+	if(files[fd].ino == console_ino || fd <= 2)
+		return(1);
+	return(0);
+}
+static void
+sys_stty(void)
+{
+	if(!is_tty_fd(u.u_arg[0]) || u.u_arg[1] == 0) {
+		u.u_error = 1;
+		return;
+	}
+	bcopy((char *)u.u_arg[1], (char *)&console_sgtty,
+	    sizeof(console_sgtty));
+	u.u_rval1 = 0;
+}
+static void
+sys_gtty(void)
+{
+	if(!is_tty_fd(u.u_arg[0]) || u.u_arg[1] == 0) {
+		u.u_error = 1;
+		return;
+	}
+	bcopy((char *)&console_sgtty, (char *)u.u_arg[1],
+	    sizeof(console_sgtty));
+	u.u_rval1 = 0;
+}
-	{0, sys_nosys},		/* 31 stty		*/
-	{0, sys_nosys},		/* 32 gtty		*/
+	{2, sys_stty},		/* 31 stty -- console sgttyb shim */
+	{2, sys_gtty},		/* 32 gtty -- console sgttyb shim */
```

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`stty V7 userspace historical-accuracy slice`.

## tabs V7 userspace historical-accuracy slice

Original at `v7/usr/src/cmd/tabs.c`.  The port lands as `cmd/tabs.c`.
The current source was compared directly against the V7 original; the
only source changes are K&R-to-C99 declarations/signatures required by
the modern cross compiler.  Function bodies, terminal type table, escape
sequences, margin handling, and `gtty`/`stty` calls are unchanged.

Exact source diff:

```diff
--- v7/usr/src/cmd/tabs.c	1979-01-10 12:02:22.000000000 -0800
+++ cmd/tabs.c	2026-05-10 07:15:58.914680234 -0700
@@ -42,9 +42,23 @@
 	{0, 0},
 };
 int	margset = 1;
+int	syslook(char *w);
+void	clear(int n);
+void	delay(int n);
+void	tabs(int n);
+void	margin(int n);
+void	escape(int c);
+void	bs(int n);
+void	nl(void);
+void	dasi450(void);
+void	tty37(void);
+void	dasi300(void);
+void	tn300(void);
+void	hp2645(void);
+void	misc(void);
 
-syslook(w)
-char *w;
+int
+syslook(char *w)
 {
 	register struct sysnod *sp;
 
@@ -54,8 +68,8 @@
 	return(0);
 }
 
-main(argc,argv)
-int argc; char **argv;
+int
+main(int argc, char **argv)
 {
 	struct sgttyb tb;
 	int type;
@@ -96,19 +110,22 @@
 	}
 }
 
-clear(n)
+void
+clear(int n)
 {
 	escape(CLR); 
 	delay(n);
 	putchar(CR); nl();
 }
 
-delay(n)
+void
+delay(int n)
 {
 	while (n--) putchar(DEL);
 }
 
-tabs(n)
+void
+tabs(int n)
 {
 	int i,j;
 
@@ -122,7 +139,8 @@
 	}
 }
 
-margin(n)
+void
+margin(int n)
 {
 	int i;
 
@@ -131,17 +149,20 @@
 	}
 }
 
-escape(c)
+void
+escape(int c)
 {
 	putchar(ESC); putchar(c);
 }
 
-bs(n)
+void
+bs(int n)
 {
 	while (n--) putchar(BS);
 }
 
-nl()
+void
+nl(void)
 {
 	putchar(NL);
 }
@@ -150,7 +171,8 @@
 
 /* ======== terminal types ======== */
 
-dasi450()
+void
+dasi450(void)
 {
 	struct sgttyb t;
 	gtty(0,&t);
@@ -160,17 +182,20 @@
 	escape(RHM); nl();
 }
 
-tty37()
+void
+tty37(void)
 {
 	putchar(SI); clear(40); bs(8); tabs(9); nl();
 }
 
-dasi300()
+void
+dasi300(void)
 {
 	clear(8); tabs(15); nl();
 }
 
-tn300()
+void
+tn300(void)
 {
 	struct sgttyb t;
 	gtty(0,&t);
@@ -180,7 +205,8 @@
 	clear(8); margin(8); escape(SET); tabs(14); nl();
 }
 
-hp2645()
+void
+hp2645(void)
 {
 	escape('3'); /*clr*/
 	putchar(CR);
@@ -188,7 +214,8 @@
 	nl();
 }
 
-misc()
+void
+misc(void)
 {
 	tabs(14); nl();
 }
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/tabs` is in `ROOT`, and `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `tabs` is in the normal `BIN` compile/link/install
  loop and clean removes `../root/bin/tabs`.
* `conf/qemu_arm/root.proto`: `tabs ---755 0 0 root/bin/tabs`.

`tabs(1)` is a userspace terminal utility and continues to use the
existing V7 `gtty`/`stty` interfaces for the `450` and `tn` terminal
types.  No compiler toolchain, network, mail/uucp, or troff files were
changed for this slice.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence are in `logs/unix-on-qemu.md` under
`tabs V7 userspace historical-accuracy slice`.

## diff/diffh V7 userspace historical-accuracy slice

Compared `cmd/diff.c` and `cmd/diffh.c` with the V7 originals in
`v7/usr/src/cmd/diff.c` and `v7/usr/src/cmd/diffh.c`.

The sources remain the V7 implementations with C99 prototypes, typed
K&R signatures/locals, explicit returns, and the local `signal(2)` ABI
casts.  This slice added only a narrow historical-compatibility repair:
V7 `isspace` was a table macro that evaluated its argument once, while
this port's current `include/ctype.h` macro evaluates arguments multiple
times.  `diff(1)` and `diffh(1)` pass `getc`/increment expressions to
`isspace`; with the local macro, `-b` consumed too much input.  The
local `diff_isspace`/`diffh_isspace` helpers preserve the V7 whitespace
set, ASCII 011 through 015 plus space, with single argument evaluation.
`diff(1)` also uses that helper while hashing `-b` lines; otherwise a
vertical-tab line and a space line hash differently and never reach the
later byte-by-byte `diff_isspace()` check.  `diff(1)` also keeps
`check()`'s `getc()` results in `int`, matching EOF-capable character
handling on Arm.

Exact source diff commands and results:

```
$ diff -u v7/usr/src/cmd/diff.c cmd/diff.c
```

```diff
--- v7/usr/src/cmd/diff.c	1979-01-10 12:02:47.000000000 -0800
+++ cmd/diff.c	2026-05-16 00:41:32.401337579 -0700
@@ -105,14 +105,44 @@
 char *tempfile;	/*used when comparing against std input*/
 char *mktemp();
 char *dummy;	/*used in resetting storage search ptr*/
+void	done(void);
+char	*talloc(int n);
+char	*ralloc(char *p, int n);
+void	noroom(void);
+void	sort(struct line *a, int n);
+void	unsort(struct line *f, int l, int *b);
+void	filename(char **pa1, char **pa2);
+void	prepare(int i, char *arg);
+void	prune(void);
+void	equiv(struct line *a, int n, struct line *b, int m, int *c);
+int	stone(int *a, int n, int *b, int *c);
+int	newcand(int x, int y, int pred);
+int	search(int *c, int k, int y);
+void	unravel(int p);
+void	check(char **argv);
+int	skipline(int f);
+void	output(char **argv);
+void	change(int a, int b, int c, int d);
+void	range(int a, int b, char *separator);
+void	fetch(long *f, int a, int b, FILE *lb, char *s);
+int	readhash(FILE *f);
+void	mesg(char *s, char *t);
+static int	diff_isspace(int c);
 
-done()
+static int
+diff_isspace(int c)
+{
+	return(c==' ' || c=='\t' || c=='\n' || c=='\v' || c=='\r' || c=='\f');
+}
+
+void
+done(void)
 {
 	unlink(tempfile);
 	exit(status);
			}
```

`readhash()` also uses `diff_isspace()` for non-newline whitespace in
`-b` mode, so the candidate hash and final check use the same
whitespace set:

```diff
@@ -611,14 +641,12 @@
-	else for(shift=0;;) {
-		switch(t=getc(f)) {
-		case -1:
+	else for(shift=0;;) {
+		t = getc(f);
+		if(t == -1)
 			return(0);
-		case '\t':
-		case ' ':
+		if(t == '\n')
+			break;
+		if(diff_isspace(t)) {
 			space++;
 			continue;
-		default:
+		}
```

The remainder of the `diff.c` delta is mechanical C99 typing of the V7
K&R definitions.  The other behavioral hunk is:

```diff
@@ -445,13 +475,13 @@
-check(argv)
-char **argv;
+void
+check(char **argv)
 {
 	register int i, j;
 	int jackpot;
 	long ctold, ctnew;
-	char c,d;
+	int c,d;
@@ -472,15 +502,15 @@
-			if(bflag && isspace(c) && isspace(d)) {
+			if(bflag && diff_isspace(c) && diff_isspace(d)) {
 				do {
 					if(c=='\n') break;
 					ctold++;
-				} while(isspace(c=getc(input[0])));
+				} while(diff_isspace(c=getc(input[0])));
 				do {
 					if(d=='\n') break;
 					ctnew++;
-				} while(isspace(d=getc(input[1])));
+				} while(diff_isspace(d=getc(input[1])));
 			}
```

```
$ diff -u v7/usr/src/cmd/diffh.c cmd/diffh.c
```

```diff
--- v7/usr/src/cmd/diffh.c	1979-01-10 12:03:03.000000000 -0800
+++ cmd/diffh.c	2026-05-16 00:41:39.857378106 -0700
@@ -15,14 +15,31 @@
 int bflag;
 int debug = 0;
 FILE *file[2];
+char	*getl(int f, long n);
+void	clrl(int f, long n);
+void	movstr(char *s, char *t);
+int	easysynch(void);
+int	output(int a, int b);
+void	change(long a, int b, long c, int d, char *s);
+void	range(long a, int b);
+int	cmp(char *s, char *t);
+FILE	*dopen(char *f1, char *f2);
+void	progerr(char *s);
+void	error(char *s, char *t);
+int	hardsynch(void);
+static int	diffh_isspace(int c);
+
+static int
+diffh_isspace(int c)
+{
+	return(c==' ' || c=='\t' || c=='\n' || c=='\v' || c=='\r' || c=='\f');
+}
```

The remainder of the `diffh.c` delta is mechanical C99 typing of the V7
K&R definitions.  The only behavioral hunk is:

```diff
@@ -192,15 +210,15 @@
-cmp(s,t)
-char *s,*t;
+int
+cmp(char *s, char *t)
 {
 	if(debug)
 		printf("%s:%s\n",s,t);
 	for(;;){
-		if(bflag&&isspace(*s)&&isspace(*t)) {
-			while(isspace(*++s)) ;
-			while(isspace(*++t)) ;
+		if(bflag&&diffh_isspace(*s)&&diffh_isspace(*t)) {
+			while(diffh_isspace(*++s)) ;
+			while(diffh_isspace(*++t)) ;
 		}
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/diff` and `root/usr/lib/diffh` are in `ROOT`;
  `root.img` depends on `cmd/*.c`.
* `lib/Makefile`: `diff` is in `BIN`; `diffh` is in `USRLIB`; clean
  removes `../root/bin/diff` and `../root/usr/lib/diffh`.
* `conf/qemu_arm/root.proto`: `/bin/diff` maps to `root/bin/diff` and
  `/usr/lib/diffh` maps to `root/usr/lib/diffh`.

No compiler toolchain, network, mail/uucp, or troff files were changed
for this slice.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence, including output-file checks for
vertical-tab equivalence under `diff -b`, direct `diffh -b`, and
`diff -hb`, are in `logs/unix-on-qemu.md` under `diff/diffh V7
userspace historical-accuracy slice`.
## dmesg(1) V7 userspace historical-accuracy slice

`cmd/dmesg.c` was compared directly against `v7/usr/src/cmd/dmesg.c`.
The source was already ported; no `cmd/dmesg.c` changes were needed for
this slice.  The only source delta is mechanical C99/Armv7 typing:

```
$ diff -u v7/usr/src/cmd/dmesg.c cmd/dmesg.c
--- v7/usr/src/cmd/dmesg.c	1979-01-10 12:01:30.000000000 -0800
+++ cmd/dmesg.c	2026-05-14 10:22:43.206743858 -0700
@@ -21,7 +21,12 @@
 	{"_msgbufp"}
 };
 
+int done(char *);
+int pdate(void);
+
+int
 main(argc, argv)
+int argc;
 char **argv;
 {
 	int mem;
@@ -81,6 +86,7 @@
 	done((char *)NULL);
 }
 
+int
 done(s)
 char *s;
 {
@@ -97,12 +103,14 @@
 	omesg.omindex = msgbufp - msgbuf;
 	write(of, (char *)&omesg, sizeof(omesg));
 	exit(s!=NULL);
+	return(0);
 }
 
+int
 pdate()
 {
 	extern char *ctime();
-	static firstime;
+	static int firstime;
 	time_t tbuf;
 
 	if (firstime==0) {
@@ -110,4 +118,5 @@
 		time(&tbuf);
 		printf("\n%.12s\n", ctime(&tbuf)+4);
 	}
+	return(0);
 }
```

Build/root wiring evidence:

* `Makefile`: `root/bin/dmesg` is in `ROOT`; `root.img` depends on
  `cmd/*.c`; `root/unix` is produced for `nlist("/unix", ...)`.
* `lib/Makefile`: `dmesg` is in `BIN`; `nlist.o` is in `LIBOBJ`;
  clean removes `../root/bin/dmesg`.
* `conf/qemu_arm/root.proto`: `/bin/dmesg` maps to `root/bin/dmesg`;
  `/unix` maps to `root/unix`.
* `dkstat` is intentionally not wired for this slice.  Existing
  `cmd/dkstat.c` was left alone, but `dkstat` was removed from the
  dmesg build/root-image wiring and from `conf/qemu_arm/root.proto`.

Runtime support was inspected rather than broadened:

* `dev/msgbuf.c` defines the V7-style `msgbuf[MSGBUFS]` ring and
  `msgbufp`.
* `dev/pl011.c` appends console output into the ring.
* `arch/armboot.c` has read-only `/dev/mem` and `/dev/kmem` pseudo-fds
  used by `dmesg` after `nlist("/unix", ...)`.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`dmesg(1) V7 userspace historical-accuracy slice`.

## du(1) V7 userspace historical-accuracy slice

`cmd/du.c` was compared directly against `v7/usr/src/cmd/du.c`.  The
source was already ported; no `cmd/du.c` changes were needed for this
slice.  The only source delta is mechanical C99/Armv7 typing:

```
$ diff -u v7/usr/src/cmd/du.c cmd/du.c
--- v7/usr/src/cmd/du.c	1979-01-10 12:01:30.000000000 -0800
+++ cmd/du.c	2026-05-13 08:47:02.251103093 -0700
@@ -18,10 +18,10 @@
 char	*rindex();
 char	*strcpy();
 
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
 {
-	register	i = 1;
+	register int	i = 1;
 	long	blocks = 0;
 	register char	*np;
 
@@ -78,7 +78,7 @@
 		return 0L;
 	}
 	if(Statb.st_nlink > 1 && (Statb.st_mode&S_IFMT)!=S_IFDIR) {
-		static linked = 0;
+		static int linked = 0;
 
 		for(i = 0; i <= linked; ++i) {
 			if(ml[i].ino==Statb.st_ino && ml[i].dev==Statb.st_dev)
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/du` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `du` is in `BIN`; clean removes `../root/bin/du`.
* `conf/qemu_arm/root.proto`: `/bin/du` maps to `root/bin/du`.

No compiler toolchain, network, mail/uucp, or troff files were changed
for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`du(1) V7 userspace historical-accuracy slice`.

## getty(8) V7 userspace historical-accuracy slice

`cmd/getty.c` was compared directly against `v7/usr/src/cmd/getty.c`.
The source was already ported; no `cmd/getty.c` changes were needed for
this slice.  The only source delta is mechanical C99/Armv7 typing:

```
$ diff -u v7/usr/src/cmd/getty.c cmd/getty.c
--- v7/usr/src/cmd/getty.c	1979-05-05 00:19:21.000000000 -0700
+++ cmd/getty.c	2026-05-13 11:01:41.833012956 -0700
@@ -8,6 +8,16 @@
 #define ERASE	'#'
 #define KILL	'@'
 
+int read(int fd, char *buf, int n);
+int write(int fd, char *buf, int n);
+int ioctl(int fd, int cmd, void *arg);
+int stty(int fd, void *buf);
+int execl(char *path, char *arg0, ...);
+void exit(int n);
+int getname(void);
+void puts(char *as);
+void putchr(int cc);
+
 struct sgttyb tmode;
 struct tchars tchars = { '\177', '\034', '\021', '\023', '\004', '\377' };
 
@@ -125,8 +135,8 @@
 	0000,0200,0200,0000,0200,0000,0000,0201
 };
 
-main(argc, argv)
-char **argv;
+int
+main(int argc, char *argv[])
 {
 	register struct tab *tabp;
 	int tname;
@@ -175,10 +185,11 @@
 	}
 }
 
-getname()
+int
+getname(void)
 {
 	register char *np;
-	register c;
+	register int c;
 	char cs;
 
 	crmod = 0;
@@ -219,8 +230,8 @@
 	return(1);
 }
 
-puts(as)
-char *as;
+void
+puts(char *as)
 {
 	register char *s;
 
@@ -229,7 +240,8 @@
 		putchr(*s++);
 }
 
-putchr(cc)
+void
+putchr(int cc)
 {
 	char c;
 	c = cc;
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/etc/getty`, `root/bin/login`, and `root/etc/init`
  are in `ROOT`; `root.img` depends on `cmd/*.c`, `lib/Makefile`,
  `conf/$(CONF)/root.proto`, and `root/etc/ttys`.
* `lib/Makefile`: `getty` is in `ETC`, so it builds to
  `root/etc/getty`; `login` is in `BIN`, so it builds to
  `root/bin/login`; clean removes `../root/etc/getty` and
  `../root/bin/login`.
* `conf/qemu_arm/root.proto`: `/etc/getty` maps to `root/etc/getty`,
  `/bin/login` maps to `root/bin/login`, `/etc/init` maps to
  `root/etc/init`, and `/etc/ttys` maps to `root/etc/ttys`.
* `cmd/init.c`: `dfork()` opens `/dev/<line>`, duplicates it to
  stdin/stdout/stderr, then executes `/etc/getty` with the command
  character as argv[1].  For the rootfs entry below this is
  `/etc/getty 4 console`.
* `root/etc/ttys`: intentionally contains only `14console`.  This is a
  rootfs/harness single-console setup: flag `1` enables the line,
  command `4` selects getty's V7 console-decwriter table, and `console`
  is the device line.  It differs from a fuller historical V7 multi-tty
  table only to match the QEMU single-console rootfs.

No compiler toolchain, network, mail/uucp, troff, login, or init source
changes were made for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`getty(8) V7 userspace historical-accuracy slice`.

## join(1) V7 userspace historical-accuracy slice

`cmd/join.c` was compared directly against `v7/usr/src/cmd/join.c`.
The source was already ported; no `cmd/join.c` changes were needed for
this slice.  The source delta is limited to mechanical C99/Armv7
typing/prototypes and widened `error()` call sites so the historical
varargs-style diagnostic helper is accepted by the strict C99 build:

```
$ diff -u v7/usr/src/cmd/join.c cmd/join.c
--- v7/usr/src/cmd/join.c	1979-05-05 01:17:00.000000000 -0700
+++ cmd/join.c	2026-05-13 08:47:49.087490901 -0700
@@ -22,7 +22,15 @@
 int	unpub2;
 int	aflg;
 
+int input(int n);
+void output(int on1, int on2);
+void error(char *s1, char *s2, char *s3, char *s4, char *s5);
+int cmp(char *s1, char *s2);
+int atoi(char *s);
+void exit(int n);
+int
 main(argc, argv)
+int argc;
 char *argv[];
 {
 	int i;
@@ -85,7 +93,7 @@
 	for (i = 0; i < no; i++)
 		olist[i]--;	/* 0 origin */
 	if (argc != 3)
-		error("usage: join [-j1 x -j2 y] [-o list] file1 file2");
+		error("usage: join [-j1 x -j2 y] [-o list] file1 file2", 0, 0, 0, 0);
 	j1--;
 	j2--;	/* everyone else believes in 0 origin */
 	s1 = ppi[F1][j1];
@@ -93,9 +101,9 @@
 	if (argv[1][0] == '-')
 		f[F1] = stdin;
 	else if ((f[F1] = fopen(argv[1], "r")) == NULL)
-		error("can't open %s", argv[1]);
+		error("can't open %s", argv[1], 0, 0, 0);
 	if ((f[F2] = fopen(argv[2], "r")) == NULL)
-		error("can't open %s", argv[2]);
+		error("can't open %s", argv[2], 0, 0, 0);
 
 #define get1() n1=input(F1)
 #define get2() n2=input(F2)
@@ -139,7 +147,9 @@
 	return(0);
 }
 
+int
 input(n)		/* get input line and split into fields */
+int n;
 {
 	register int i, c;
 	char *bp;
@@ -167,6 +177,7 @@
 	return(i);
 }
 
+void
 output(on1, on2)	/* print items from olist */
 int on1, on2;
 {
@@ -198,8 +209,9 @@
 	}
 }
 
+void
 error(s1, s2, s3, s4, s5)
-char *s1;
+char *s1, *s2, *s3, *s4, *s5;
 {
 	fprintf(stderr, "join: ");
 	fprintf(stderr, s1, s2, s3, s4, s5);
@@ -207,6 +219,7 @@
 	exit(1);
 }
 
+int
 cmp(s1, s2)
 char *s1, *s2;
 {
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/join` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `join` is in `BIN`; clean removes
  `../root/bin/join`.
* `conf/qemu_arm/root.proto`: `/bin/join` maps to `root/bin/join`.

No compiler toolchain, network, mail/uucp, or troff files were changed
for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`join(1) V7 userspace historical-accuracy slice`.

## kill(1) V7 userspace historical-accuracy slice

`cmd/kill.c` was compared directly against `v7/usr/src/cmd/kill.c`.
The source was already ported; no `cmd/kill.c` changes were needed for
this slice.  The behavior remains the V7 implementation: optional
numeric `-signo`, default `SIGTERM`, decimal-only pid arguments, the
historical usage string, and `pid: sys_errlist[errno]` diagnostics.
The source delta is limited to C99/Armv7 declarations and typed locals:

```
$ diff -u v7/usr/src/cmd/kill.c cmd/kill.c
--- v7/usr/src/cmd/kill.c	1979-01-10 12:01:40.000000000 -0800
+++ cmd/kill.c	2026-05-10 07:15:58.906680187 -0700
@@ -3,14 +3,21 @@
  */
 
 #include <signal.h>
+#include <stdio.h>
 
+int kill(int pid, int sig);
+int atoi(char *s);
+void exit(int n);
+extern char *sys_errlist[];
+int errno;
+
+int
 main(argc, argv)
+int argc;
 char **argv;
 {
-	register signo, pid, res;
+	register int signo, pid, res;
 	int errlev;
-	extern char *sys_errlist[];
-	extern errno;
 
 	errlev = 0;
 	if (argc <= 1) {
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/kill` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `kill` is in `BIN`; clean removes
  `../root/bin/kill`.
* `conf/qemu_arm/root.proto`: `/bin/kill` maps to `root/bin/kill`.

No compiler toolchain, network, mail/uucp, troff, or unrelated source
files were changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`kill(1) V7 userspace historical-accuracy slice`.

## ln(1) V7 userspace historical-accuracy slice

`cmd/ln.c` was compared directly against `v7/usr/src/cmd/ln.c`.  The
source was already ported; no `cmd/ln.c` changes were needed for this
slice.  The behavior remains the V7 implementation: `ln [-f] target
[newname]`, basename defaulting when `newname` is omitted, directory
target expansion to `directory/basename`, source-directory rejection
without `-f`, and the V7 diagnostics.

Exact source delta:

```diff
$ diff -u v7/usr/src/cmd/ln.c cmd/ln.c
--- v7/usr/src/cmd/ln.c	1979-01-10 12:01:43.000000000 -0800
+++ cmd/ln.c	2026-05-10 07:15:58.906680187 -0700
@@ -7,8 +7,8 @@
 #include "stdio.h"
 char	*rindex();
 
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
 {
 	struct stat statb;
 	register char *np;
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/ln` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `ln` is in `BIN`; clean removes `../root/bin/ln`.
* `conf/qemu_arm/root.proto`: `/bin/ln` maps to `root/bin/ln`.

No compiler toolchain, network, mail/uucp, troff, or unrelated source
files were changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`ln(1) V7 userspace historical-accuracy slice`.

## mkdir(1) V7 userspace historical-accuracy slice

`cmd/mkdir.c` was compared directly against `v7/usr/src/cmd/mkdir.c`.
The source was already ported; no `cmd/mkdir.c` changes were needed for
this slice.  The behavior remains the V7 implementation: ignore the
same signals, reject empty argument lists with `mkdir: arg count`, check
write access to the parent path, create the directory with `mknod`, set
ownership to the caller, and link `.` and `..` explicitly with the V7
diagnostics.

Exact source delta:

```diff
$ diff -u v7/usr/src/cmd/mkdir.c cmd/mkdir.c
--- v7/usr/src/cmd/mkdir.c	1979-01-10 12:01:58.000000000 -0800
+++ cmd/mkdir.c	2026-05-10 07:15:58.906680187 -0700
@@ -8,9 +8,10 @@
 int	Errors = 0;
 char	*strcat();
 char	*strcpy();
+void	mkdir(char *d);
 
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
 {
 
 	signal(SIGHUP, SIG_IGN);
@@ -28,11 +29,11 @@
 	exit(Errors!=0);
 }
 
-mkdir(d)
-char *d;
+void
+mkdir(char *d)
 {
 	char pname[128], dname[128];
-	register i, slash = 0;
+	register int i, slash = 0;
 
 	pname[0] = '\0';
 	for(i = 0; d[i]; ++i)
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/mkdir` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `mkdir` is in `BIN`; clean removes
  `../root/bin/mkdir`.
* `conf/qemu_arm/root.proto`: `/bin/mkdir` maps to `root/bin/mkdir`.

No compiler toolchain, network, mail/uucp, troff, kernel, filesystem,
or unrelated source files were changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`mkdir(1) V7 userspace historical-accuracy slice`.

## mknod(1) V7 userspace historical-accuracy slice

`cmd/mknod.c` was compared directly against `v7/usr/src/cmd/mknod.c`.
The source was already ported; no `cmd/mknod.c` changes were needed for
this slice.  The implementation remains the V7 behavior: accept only
five arguments, print `arg count` plus usage for the empty-argument
case, accept only `b` or `c`, parse decimal major/minor numbers, call
`mknod(name, mode, (major<<8)|minor)`, and preserve the historical
usage-path fall-through return behavior.

Exact source delta:

```diff
$ diff -u v7/usr/src/cmd/mknod.c cmd/mknod.c
--- v7/usr/src/cmd/mknod.c	1979-01-10 12:02:00.000000000 -0800
+++ cmd/mknod.c	2026-05-10 07:15:58.906680187 -0700
@@ -1,3 +1,8 @@
+#include <stdio.h>
+
+int number(char *s);
+
+int
 main(argc, argv)
 int argc;
 char **argv;
@@ -27,6 +32,7 @@
 	printf("usage: mknod name b/c major minor\n");
 }
 
+int
 number(s)
 char *s;
 {
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/mknod` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `mknod` is in `BIN`; clean removes
  `../root/bin/mknod`.
* `conf/qemu_arm/root.proto`: `/bin/mknod` maps to `root/bin/mknod`.

No `mkfs` source or wiring was added for this slice.  No compiler
toolchain, network, mail/uucp, troff, kernel, filesystem, or unrelated
source files were changed.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`mknod(1) V7 userspace historical-accuracy slice`.

## mount(1) V7 userspace historical-accuracy slice

`cmd/mount.c` was compared directly against `v7/usr/src/cmd/mount.c`.
The userspace source was already ported with only the minimal C99 entry
point change; no `cmd/mount.c` changes were needed for this slice.  The
implementation remains the V7 behavior: read `/etc/mtab`, print
`spec on file` entries when called with no arguments, reject too few
arguments with `arg count` and status 1, pass the optional fourth
argument as the read-only flag, call `mount(2)`, report syscall failure
with `perror("mount")`, and update `/etc/mtab` after a successful mount.

Exact mount userspace source delta:

```diff
$ diff -u v7/usr/src/cmd/mount.c cmd/mount.c
--- v7/usr/src/cmd/mount.c	1979-01-10 12:02:00.000000000 -0800
+++ cmd/mount.c	2026-05-13 09:33:07.231083965 -0700
@@ -8,8 +8,8 @@
 	char	spec[NAMSIZ];
 } mtab[NMOUNT];
 
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
 {
 	register int ro;
 	register struct mtab *mp;
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/mount` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `mount` is in `BIN`, so the root build compiles
  `cmd/mount.c` to `root/bin/mount`.
* `conf/qemu_arm/root.proto`: `/bin/mount` maps to `root/bin/mount`.

One kernel dispatch bug was found while verifying mount(1): syscall 21
was still wired to an Arm boot shim that always returned success.  That
made the unmodified V7 `mount(1)` skip its historical `perror("mount")`
path for bad operands.  The fix keeps userspace historical behavior
intact and routes the syscall through resident V7 `sys/sys3.c::smount()`
via:

* `arch/u_bridge.c`: added `v7_mount_call(special, dir, ro)`, which
  seeds `u.u_ap`, `u.u_dirp`, and calls `smount()`, returning
  `u.u_error`.
* `arch/armboot.c`: syscall 21 now dispatches to `sys_mount_v7()`, which
  maps the returned V7 error into the normal syscall return path.

No compiler toolchain, network, mail/uucp, troff, or unrelated userspace
source was changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`mount(1) V7 userspace historical-accuracy slice`.

## umount(1) V7 userspace historical-accuracy slice

`cmd/umount.c` was compared directly against
`v7/usr/src/cmd/umount.c`.  The userspace source was already ported
with only the minimal C99 changes; no `cmd/umount.c` edit was needed
for this slice.  The implementation remains the V7 behavior: call
`sync()`, read `/etc/mtab`, reject the wrong argument count with
`arg count`, call `umount(2)`, report syscall failure with
`perror("umount")`, strip trailing and leading path components from the
operand before matching `mtab[].spec`, rewrite `/etc/mtab` on a match,
or print `<name> not in mount table`.

Exact umount userspace source delta:

```diff
$ diff -u v7/usr/src/cmd/umount.c cmd/umount.c
--- v7/usr/src/cmd/umount.c	1979-01-10 12:02:38.000000000 -0800
+++ cmd/umount.c	2026-05-13 09:33:49.087473735 -0700
@@ -1,3 +1,5 @@
+#include <stdio.h>
+
 #define	NMOUNT	16
 #define	NAMSIZ	32
 
@@ -6,8 +8,8 @@
 	char	spec[NAMSIZ];
 } mtab[NMOUNT];
 
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
 {
 	register struct mtab *mp;
 	register char *p1, *p2;
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/umount` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `umount` is in `BIN`, so the root build compiles
  `cmd/umount.c` to `root/bin/umount`.
* `conf/qemu_arm/root.proto`: `/bin/umount` maps to
  `root/bin/umount`.

One kernel dispatch bug was found while verifying umount(1): syscall 22
was still wired to an Arm boot shim that always returned success.  That
made the unmodified V7 `umount(1)` skip its historical
`perror("umount")` path for bad operands and continue into the mtab
search.  The fix keeps userspace historical behavior intact and routes
only syscall 22 through resident V7 `sys/sys3.c::sumount()`:

* `arch/u_bridge.c`: added `v7_umount_call(special)`, which seeds
  `u.u_ap`, `u.u_dirp`, and calls `sumount()`, returning `u.u_error`.
* `arch/armboot.c`: added `sys_umount_v7()` and changed sysent slot 22
  from the old `sys_umount` placeholder to `sys_umount_v7`.

Exact bridge source delta for this slice:

```diff
--- arch/u_bridge.c
+++ arch/u_bridge.c
@@
 extern void link(void);
 extern void mknod(void);
+extern void smount(void);
+extern void sumount(void);
 extern void close(void);
@@
 v7_mount_call(char *special, char *dir, int ro)
 {
@@
 	smount();
 	return u.u_error;
 }
+
+/* v7_umount_call:
+ *   args[0] is the block-special path.  v7 sumount() shares getmdev()
+ *   with smount(), so bad operands must go through namei()/block-device
+ *   validation and report u.u_error instead of succeeding in the old
+ *   armboot stub.
+ */
+int
+v7_umount_call(char *special)
+{
+	int args[1];
+
+	args[0] = (int)(long)special;
+	u.u_dirp = (caddr_t)special;
+	u.u_segflg = 1;
+	u.u_ap = args;
+	u.u_error = 0;
+	u.u_r.r_val1 = 0;
+	u.u_r.r_val2 = 0;
+	sumount();
+	return u.u_error;
+}
```

```diff
--- arch/armboot.c
+++ arch/armboot.c
@@
 __attribute__((unused))
 static void
 sys_mount(void) { u.u_rval1 = 0; }
 
+/* Real-v7 umount path: forwards the block-special path through
+ * sys/sys3.c::sumount().  This keeps umount(1)'s failure behavior tied
+ * to V7 getmdev()/namei() validation instead of the old always-success
+ * placeholder for sysent[22]. */
+extern int v7_umount_call(char *special);
+
+static void
+sys_umount_v7(void)
+{
+	int err;
+
+	err = v7_umount_call((char *)u.u_arg[0]);
+	if(err) u.u_error = err;
+	else u.u_rval1 = 0;
+}
+
+__attribute__((unused))
 static void
 sys_umount(void) { u.u_rval1 = 0; }
@@
-	{1, sys_umount},	/* 22 umount		*/
+	{1, sys_umount_v7},	/* 22 umount -- routed through sys/sys3.c */
```

No compiler toolchain, network, mail/uucp, troff, or unrelated
userspace source was changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`umount(1) V7 userspace historical-accuracy slice`.

### diff3(1) V7 userspace historical-accuracy slice

Compared `cmd/diff3.c` with the V7 original in
`v7/usr/src/cmd/diff3.c`.  The port was already present; no source
changes were made for this slice.  The only differences are minimal
C99/Armv7 compatibility edits: explicit `int` return/argument types,
old-style prototypes for formerly implicit functions, `register int`,
an `int` cast for `sizeof(line)`, explicit `return(0)` on functions that
now return `int`, one `(void)rold` for an unused parameter, and one
comment whitespace change.

Exact source diff:

```diff
$ diff -u v7/usr/src/cmd/diff3.c cmd/diff3.c
--- v7/usr/src/cmd/diff3.c	1979-01-10 12:03:09.000000000 -0800
+++ cmd/diff3.c	2026-05-13 21:14:51.033631224 -0700
@@ -3,7 +3,7 @@
 
 /* diff3 - 3-way differential file comparison*/
 
-/* diff3 [-e] d13 d23 f1 f2 f3 
+/* diff3 [-e] d13 d23 f1 f2 f3
  *
  * d13 = diff report on f1 vs f3
  * d23 = diff report on f2 vs f3
@@ -42,10 +42,16 @@
 int eflag;
 int debug  = 0;
 
+int readin(), number(), digit(), getchange(), getline(), merge(),
+    separate(), change(), prange(), keep(), skip(), duplicate(),
+    repos(), trouble(), edit(), edscript();
+
+int
 main(argc,argv)
+int argc;
 char **argv;
 {
-	register i,m,n;
+	register int i,m,n;
 	if(*argv[1]=='-') {
 		switch(argv[1][1]) {
 		default:
@@ -72,6 +78,7 @@
 			exit(1);
 		}
 	merge(m,n);
+	return(0);
 }
 
 /*pick up the line numbers of allcahnges from
@@ -82,11 +89,12 @@
  * out of existence)
 */
 
+int
 readin(name,dd)
 char *name;
 struct diff *dd;
 {
-	register i;
+	register int i;
 	int a,b,c,d;
 	char kind;
 	char *p;
@@ -125,21 +133,25 @@
 	return(i);
 }
 
+int
 number(lc)
 char **lc;
 {
-	register nn;
+	register int nn;
 	nn = 0;
 	while(digit(**lc))
 		nn = nn*10 + *(*lc)++ - '0';
 	return(nn);
 }
 
+int
 digit(c)
+int c;
 {
 	return(c>='0'&&c<='9');
 }
 
+int
 getchange(b)
 FILE *b;
 {
@@ -149,11 +161,12 @@
 	return(0);
 }
 
+int
 getline(b)
 FILE *b;
 {
-	register i, c;
-	for(i=0;i<sizeof(line)-1;i++) {
+	register int i, c;
+	for(i=0;i<(int)sizeof(line)-1;i++) {
 		c = getc(b);
 		if(c==EOF)
 			break;
@@ -166,7 +179,9 @@
 	return(0);
 }
 
+int
 merge(m1,m2)
+int m1, m2;
 {
 	register struct diff *d1, *d2, *d3;
 	int dup;
@@ -263,36 +278,44 @@
 	}
 	if(eflag)
 		edscript(j);
+	return(0);
 }
 
+int
 separate(s)
 char *s;
 {
 	printf("====%s\n",s);
+	return(0);
 }
 
 /*	the range of ines rold.from thru rold.to in file i
  *	is to be changed. it is to be printed only if
  *	it does not duplicate something to be printed later
 */
+int
 change(i,rold,dup)
+int i;
 struct range *rold;
+int dup;
 {
 	printf("%d:",i);
 	last[i] = rold->to;
 	prange(rold);
 	if(dup)
-		return;
+		return(0);
 	if(debug)
-		return;
+		return(0);
 	i--;
 	skip(i,rold->from,(char *)0);
 	skip(i,rold->to,"  ");
+	return(0);
 }
 
 /*	print the range of line numbers, rold.from  thru rold.to
  *	as n1,n2 or n1
 */
+int
 prange(rold)
 struct range *rold;
 {
@@ -304,6 +327,7 @@
 			printf(",%d",rold->to-1);
 		printf("c\n");
 	}
+	return(0);
 }
 
 /*	no difference was reported by diff between file 1(or 2)
@@ -311,25 +335,31 @@
  *	must be ginned up to correspond to the change reported
  *	in the other file
 */
+int
 keep(i,rold,rnew)
+int i;
 struct range *rold, *rnew;
 {
-	register delta;
+	register int delta;
 	struct range trange;
+	(void)rold;
 	delta = last[3] - last[i];
 	trange.from = rnew->from - delta;
 	trange.to = rnew->to - delta;
 	change(i,&trange,1);
+	return(0);
 }
 
 /*	skip to just befor line number from in file i
  *	if "pr" is nonzero, print all skipped stuff
  * w	with string pr as a prefix
 */
+int
 skip(i,from,pr)
+int i, from;
 char *pr;
 {
-	register j,n;
+	register int j,n;
 	for(n=0;cline[i]<from-1;n+=j) {
 		if((j=getline(fp[i]))==0)
 			trouble();
@@ -344,11 +374,12 @@
  *	(in file 1) contains exactly the same data
  *	as the new range (in file 2)
 */
+int
 duplicate(r1,r2)
 struct range *r1, *r2;
 {
-	register c,d;
-	register nchar;
+	register int c,d;
+	register int nchar;
 	int nline;
 	if(r1->to-r1->from != r2->to-r2->from)
 		return(0);
@@ -364,7 +395,7 @@
 			nchar++;
 			if(c!=d) {
 				repos(nchar);
-				return;
+				return(0);
 			}
 		} while(c!= '\n');
 	}
@@ -372,23 +403,30 @@
 	return(1);
 }
 
+int
 repos(nchar)
+int nchar;
 {
-	register i;
-	for(i=0;i<2;i++) 
+	register int i;
+	for(i=0;i<2;i++)
 		fseek(fp[i], (long)-nchar, 1);
+	return(0);
 }
 
+int
 trouble()
 {
 	fprintf(stderr,"diff3: logic error\n");
 	abort();
+	return(0);
 }
 
 /*	collect an editing script for later regurgitation
 */
+int
 edit(diff,dup,j)
 struct diff *diff;
+int dup, j;
 {
 	if(((dup+1)&eflag)==0)
 		return(j);
@@ -403,9 +441,11 @@
 }
 
 /*		regurgitate */
+int
 edscript(n)
+int n;
 {
-	register j,k;
+	register int j,k;
 	char block[512];
 	for(n=n;n>0;n--) {
 		prange(&de[n].old);
@@ -418,4 +458,5 @@
 		}
 		printf(".\n");
 	}
+	return(0);
 }
```

Build/root image wiring was already present and unchanged:

* `Makefile`: `root/bin/diff3` is in `ROOT`; `root.img` depends on
  `cmd/*.c`.
* `lib/Makefile`: `diff3` is in `BIN`, so the root build compiles
  `cmd/diff3.c` to `root/bin/diff3`.
* `conf/qemu_arm/root.proto`: `/bin/diff3` maps to
  `root/bin/diff3`.

No compiler toolchain, network, mail/uucp, troff, or unrelated source
was changed for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build and live QEMU evidence is in `logs/unix-on-qemu.md` under
`diff3(1) V7 userspace historical-accuracy slice`.

### mkfs host tool V7 historical-accuracy slice

Compared `tools/mkfs.c` against `v7/usr/src/cmd/mkfs.c` with:

```
$ diff -u v7/usr/src/cmd/mkfs.c tools/mkfs.c || true
```

The source was already in the expected host-tool state for this slice,
so no source, Makefile, or proto edits were made.  The exact intentional
source delta is:

```diff
--- v7/usr/src/cmd/mkfs.c	1979-01-10 12:01:59.000000000 -0800
+++ tools/mkfs.c	2026-05-15 13:41:24.367469179 -0700
@@ -6,18 +6,31 @@
 #define	NINDIR	(BSIZE/sizeof(daddr_t))
 #define	NDIRECT	(BSIZE/sizeof(struct direct))
 #define	LADDR	10
+#define	MAXFILEBLK	(LADDR+NINDIR+(NINDIR*NINDIR))
 #define	MAXFN	500
 #define	itoo(x)	(int)((x+15)&07)
 #ifndef STANDALONE
 #include <stdio.h>
-#include <a.out.h>
+#include <stdlib.h>
+#include <unistd.h>
+#include <fcntl.h>
+#include <time.h>
 #endif
-#include <sys/param.h>
-#include <sys/ino.h>
-#include <sys/inode.h>
-#include <sys/filsys.h>
-#include <sys/fblk.h>
-#include <sys/dir.h>
+#include "../include/sys/param.h"
+#include "../include/sys/ino.h"
+#include "../include/sys/inode.h"
+#include "../include/sys/filsys.h"
+#include "../include/sys/fblk.h"
+#include "../include/sys/dir.h"
+/* Pack longs into pure LE 24-bit; matches arch/armboot.c::addr(). */
+int ltol3(cp, lp, n) char *cp; long *lp; int n; {
+	int i; long v;
+	for(i=0; i<n; i++) {
+		v = lp[i];
+		*cp++ = v; *cp++ = v >> 8; *cp++ = v >> 16;
+	}
+	return(0);
+}
 time_t	utime;
 #ifndef STANDALONE
 FILE 	*fin;
@@ -29,15 +42,12 @@
 char	*charp;
 char	buf[BSIZE];
 union {
-	struct fblk fb;
+	struct fblk;
 	char pad1[BSIZE];
 } fbuf;
-#ifndef STANDALONE
-struct exec head;
-#endif
 char	string[50];
 union {
-	struct filsys fs;
+	struct filsys;
 	char pad2[BSIZE];
 } filsys;
 char	*fsys;
@@ -114,7 +124,7 @@
 		if(n > 65500/NIPB)
 			n = 65500/NIPB;
 		filsys.s_isize = n + 2;
-		printf("isize = %D\n", n*NIPB);
+		printf("isize = %ld\n", n*NIPB);
 		charp = "d--777 0 0 $ ";
 		goto f3;
 	}
@@ -122,37 +132,21 @@
 #ifndef STANDALONE
 	/*
 	 * get name of boot load program
-	 * and read onto block 0
+	 * (skipped: PDP-11 a.out format is not used on this port)
 	 */
 
 	getstr();
 	f = open(string, 0);
-	if(f < 0) {
-		printf("%s: cannot  open init\n", string);
-		goto f2;
-	}
-	read(f, (char *)&head, sizeof head);
-	if(head.a_magic != A_MAGIC1) {
-		printf("%s: bad format\n", string);
-		goto f1;
-	}
-	c = head.a_text + head.a_data;
-	if(c > BSIZE) {
-		printf("%s: too big\n", string);
-		goto f1;
-	}
-	read(f, buf, c);
-	wtfs((long)0, buf);
-
-f1:
-	close(f);
+	if(f < 0)
+		printf("%s: cannot open init\n", string);
+	else
+		close(f);
 
 	/*
 	 * get total disk size
 	 * and inode block size
 	 */
 
-f2:
 	filsys.s_fsize = getnum();
 	n = getnum();
 	n /= NIPB;
@@ -200,7 +194,7 @@
 	struct inode in;
 	int dbc, ibc;
 	char db[BSIZE];
-	daddr_t ib[NINDIR];
+	daddr_t ib[MAXFILEBLK];
 	int i, f, c;
 
 	/*
@@ -232,7 +226,7 @@
 	in.i_number = ino;
 	for(i=0; i<BSIZE; i++)
 		db[i] = 0;
-	for(i=0; i<NINDIR; i++)
+	for(i=0; i<MAXFILEBLK; i++)
 		ib[i] = (daddr_t)0;
 	in.i_nlink = 1;
 	in.i_size = 0;
@@ -310,10 +304,11 @@
 char c, *s;
 {
 	int i;
+	int m[4] = {m0, m1, m2, m3};
 
 	for(i=0; s[i]; i++)
 		if(c == s[i])
-			return((&m0)[i]);
+			return(m[i]);
 	printf("%c/%s: bad mode\n", c, string);
 	error = 1;
 	return(0);
@@ -392,7 +387,7 @@
 	lseek(fso, bno*BSIZE, 0);
 	n = write(fso, bf, BSIZE);
 	if(n != BSIZE) {
-		printf("write error: %D\n", bno);
+		printf("write error: %ld\n", bno);
 		exit(1);
 	}
 }
@@ -465,6 +460,11 @@
 	int i;
 	daddr_t bno;
 
+	if(*aibc >= MAXFILEBLK) {
+		printf("indirect block full\n");
+		error = 1;
+		return;
+	}
 	bno = alloc();
 	wtfs(bno, db);
 	for(i=0; i<BSIZE; i++)
@@ -472,11 +472,6 @@
 	*adbc = 0;
 	ib[*aibc] = bno;
 	(*aibc)++;
-	if(*aibc >= NINDIR) {
-		printf("indirect block full\n");
-		error = 1;
-		*aibc = 0;
-	}
 }
 
 getch()
@@ -553,8 +548,8 @@
 daddr_t *ib;
 {
 	struct dinode *dp;
-	daddr_t d;
-	int i;
+	daddr_t d, single[NINDIR], dbl[NINDIR];
+	int i, j, k, n;
 
 	filsys.s_tinode--;
 	d = itod(ip->i_number);
@@ -581,18 +576,41 @@
 
 	case IFDIR:
 	case IFREG:
-		for(i=0; i<*aibc; i++) {
-			if(i >= LADDR)
-				break;
-			ip->i_un.i_addr[i] = ib[i];
+		for(i=0; i<NINDIR; i++) {
+			single[i] = (daddr_t)0;
+			dbl[i] = (daddr_t)0;
 		}
-		if(*aibc >= LADDR) {
+		for(i=0; i<*aibc && i<LADDR; i++)
+			ip->i_un.i_addr[i] = ib[i];
+		if(*aibc > LADDR) {
+			n = *aibc - LADDR;
+			if(n > NINDIR)
+				n = NINDIR;
+			for(i=0; i<n; i++)
+				single[i] = ib[LADDR+i];
 			ip->i_un.i_addr[LADDR] = alloc();
-			for(i=0; i<NINDIR-LADDR; i++) {
-				ib[i] = ib[i+LADDR];
-				ib[i+LADDR] = (daddr_t)0;
+			wtfs(ip->i_un.i_addr[LADDR], (char *)single);
+		}
+		if(*aibc > LADDR+NINDIR) {
+			n = *aibc - LADDR - NINDIR;
+			if(n > NINDIR*NINDIR) {
+				printf("indirect block full\n");
+				error = 1;
+				n = NINDIR*NINDIR;
+			}
+			ip->i_un.i_addr[LADDR+1] = alloc();
+			k = LADDR + NINDIR;
+			for(i=0; i<NINDIR && n>0; i++) {
+				for(j=0; j<NINDIR; j++)
+					single[j] = (daddr_t)0;
+				for(j=0; j<NINDIR && n>0; j++) {
+					single[j] = ib[k++];
+					n--;
+				}
+				dbl[i] = alloc();
+				wtfs(dbl[i], (char *)single);
 			}
-			wtfs(ip->i_un.i_addr[LADDR], (char *)ib);
+			wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);
 		}
 
 	case IFBLK:
```

Rationale for the intentional host-tool delta:

* Header paths use this tree's V7-compatible headers, with standard
  host headers added only for functions used while building images.
* The PDP-11 `a.out` boot-block copy is skipped because this port boots
  QEMU with `-kernel unix`; the prototype's first token is still read so
  the file format remains compatible.
* `%D` formats and the old `(&m0)[i]` argument-address trick were
  replaced with host-C-compatible forms.
* A local `ltol3()` keeps V7's 24-bit disk-address packing without
  pulling in target library code.
* The direct/single/double-indirect expansion preserves V7 inode block
  addressing while allowing the host image builder to place the larger
  present-day root payload.  Without this, large regular files can exceed
  the original temporary `NINDIR` block-list scratch space during image
  construction.
* `Makefile`, `conf/qemu_arm/root.proto`, and
  `conf/qemu_arm/auxfs.proto` were inspected only as build/test inputs
  and were not edited for this slice.

`test_serv inventory` was attempted, but this environment does not
provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Rebuild and live QEMU evidence is in `logs/unix-on-qemu.md` under
`mkfs host tool V7 historical-accuracy slice`.

## arcv(1) V7 port slice

Source/header provenance:

* `cmd/arcv.c` was ported from `v7/usr/src/cmd/arcv.c`.
* `include/ar.h` was copied from `v7/usr/include/ar.h` because
  `arcv.c` includes `<ar.h>` for `ARMAG`.

Exact header diff:

```diff
--- /dev/null
+++ include/ar.h
@@
+#define	ARMAG	0177545
+struct	ar_hdr {
+	char	ar_name[14];
+	long	ar_date;
+	char	ar_uid;
+	char	ar_gid;
+	int	ar_mode;
+	long	ar_size;
+};
```

Exact command-port diff summary:

```diff
--- v7/usr/src/cmd/arcv.c
+++ cmd/arcv.c
@@
-#include <signal.h>
-#include <ar.h>
+#include <signal.h>
+#include <stdio.h>
+#include <ar.h>
@@
-#define	omag	0177555
+#define	OMAG	0177555
@@
-struct	ar_hdr nh;
-struct
-{
-	char	oname[8];
-	long	odate;
-	char	ouid;
-	char	omode;
-	unsigned siz;
-} oh;
+struct oar_hdr {
+	char	oname[8];
+	char	odate[4];
+	char	ouid;
+	char	omode;
+	char	osize[2];
+};
@@
-union {
-	char	buf[512];
-	int	magic;
-} b;
+static union {
+	char	buf[512];
+	char	magic[2];
+} b;
@@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char **argv)
```

Full source diff from `v7/usr/src/cmd/arcv.c` to `cmd/arcv.c`:

```diff
--- v7/usr/src/cmd/arcv.c
+++ cmd/arcv.c
@@ -1,48 +1,75 @@
 /*
  * Convert old to new archive format
-*/
+ */
 
 #include <signal.h>
+#include <stdio.h>
 #include <ar.h>
 
-#define	omag	0177555
+#define	OMAG	0177555
 
-struct	ar_hdr nh;
-struct
-{
+struct oar_hdr {
 	char	oname[8];
-	long	odate;
+	char	odate[4];
 	char	ouid;
 	char	omode;
-	unsigned siz;
-} oh;
+	char	osize[2];
+};
 
-char	*tmp;
-char	*mktemp();
-int	f;
-int	tf;
-union {
+static char	*tmp;
+static int	f;
+static int	tf;
+static union {
 	char	buf[512];
-	int	magic;
+	char	magic[2];
 } b;
 
-main(argc, argv)
-char *argv[];
+static unsigned short
+getshort(char *p)
 {
-	register i;
+	return ((unsigned short)(unsigned char)p[0]) |
+	    ((unsigned short)(unsigned char)p[1] << 8);
+}
+
+static void
+putshort(char *p, unsigned short v)
+{
+	p[0] = v & 0377;
+	p[1] = (v >> 8) & 0377;
+}
+
+static void
+putlong(char *p, char *v)
+{
+	p[0] = v[0];
+	p[1] = v[1];
+	p[2] = v[2];
+	p[3] = v[3];
+}
+
+static void
+putarhdr(char *p, struct oar_hdr *oh)
+{
+	int i;
+
+	for(i = 0; i < 8; i++)
+		p[i] = oh->oname[i];
+	for(; i < 14; i++)
+		p[i] = 0;
+	putlong(&p[14], oh->odate);
+	p[18] = oh->ouid;
+	p[19] = 1;
+	putshort(&p[20], 0666);
+	putshort(&p[22], getshort(oh->osize));
+	putshort(&p[24], 0);
+}
 
-	tmp = mktemp("/tmp/arcXXXXX");
-	for(i=1; i<4; i++)
-		signal(i, SIG_IGN);
-	for(i=1; i<argc; i++)
-		conv(argv[i]);
-	unlink(tmp);
-}
-
-conv(fil)
-char *fil;
+static void
+conv(char *fil)
 {
-	register unsigned i, n;
+	unsigned int i, n;
+	struct oar_hdr oh;
+	char nh[26];
 
 	f = open(fil, 2);
 	if(f < 0) {
@@ -56,29 +83,24 @@
 		close(f);
 		return;
 	}
-	b.magic = 0;
-	read(f, (char *)&b.magic, sizeof(b.magic));
-	if(b.magic != omag) {
+	b.magic[0] = 0;
+	b.magic[1] = 0;
+	read(f, b.magic, sizeof(b.magic));
+	if(getshort(b.magic) != OMAG) {
 		printf("arcv: %s not archive format\n", fil);
 		close(tf);
 		close(f);
 		return;
 	}
-	b.magic = ARMAG;
-	write(tf, (char *)&b.magic, sizeof(b.magic));
+	putshort(b.magic, ARMAG);
+	write(tf, b.magic, sizeof(b.magic));
 loop:
 	i = read(f, (char *)&oh, sizeof(oh));
 	if(i != sizeof(oh))
 		goto out;
-	for(i=0; i<8; i++)
-		nh.ar_name[i] = oh.oname[i];
-	nh.ar_size = oh.siz;
-	nh.ar_uid = oh.ouid;
-	nh.ar_gid = 1;
-	nh.ar_mode = 0666;
-	nh.ar_date = oh.odate;
-	n = (oh.siz+1) & ~01;
-	write(tf, (char *)&nh, sizeof(nh));
+	putarhdr(nh, &oh);
+	n = (getshort(oh.osize)+1) & ~01;
+	write(tf, nh, sizeof(nh));
 	while(n > 0) {
 		i = 512;
 		if(n < i)
@@ -91,8 +113,23 @@
 out:
 	lseek(f, 0L, 0);
 	lseek(tf, 0L, 0);
-	while((i=read(tf, b.buf, 512)) > 0)
+	while((i = read(tf, b.buf, 512)) > 0)
 		write(f, b.buf, i);
 	close(f);
 	close(tf);
 }
+
+int
+main(int argc, char **argv)
+{
+	int i;
+	char tbuf[] = "/tmp/arcXXXXX";
+
+	tmp = mktemp(tbuf);
+	for(i = 1; i < 4; i++)
+		signal(i, SIG_IGN);
+	for(i = 1; i < argc; i++)
+		conv(argv[i]);
+	unlink(tmp);
+	return 0;
+}
```

Additional C99/Armv7-only changes in `cmd/arcv.c`:

* K&R definitions were converted to prototypes and `static` helpers.
* `stdio.h` was included for the local libc syscall/stdio declarations.
* The old archive header is read as the historical 16 on-disk bytes,
  not as an Arm C struct with 32-bit `unsigned` and padding.
* The new archive header is emitted as the historical 26 on-disk bytes
  (`name[14]`, `long date`, `char uid`, `char gid`, 16-bit mode,
  32-bit size), not as the target compiler's padded `struct ar_hdr`.
* Two-byte `ARMAG`/old magic reads and writes are explicit because V7
  `int` was 16 bits while this Armv7 target's `int` is 32 bits.

Exact wiring diffs for this slice:

```diff
--- Makefile
+++ Makefile
@@
-	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
-	root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/sum \
+	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
+	root/bin/arcv root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/sum \
--- lib/Makefile
+++ lib/Makefile
@@
-BIN = login cat echo ls pwd sync rev yes wc basename sum ...
+BIN = login cat echo ls pwd sync arcv rev yes wc basename sum ...
@@
 	rm -f ../root/bin/rev
+	rm -f ../root/bin/arcv
--- conf/qemu_arm/root.proto
+++ conf/qemu_arm/root.proto
@@
 		at	---755 0 0 root/bin/at
+		arcv	---755 0 0 root/bin/arcv
 		awk	---755 0 0 root/bin/awk
```

No `learn`, `games/chess`, toolchain/network/troff/mail/uucp commands
were started or wired by this slice.

## learn(1) morefiles-course data slice

This slice adds only the V7 `learn morefiles` course data.  No new
archive parser was introduced: `Makefile` reuses
`tools/extract-old-ar.py` to extract `v7/usr/lib/learn/morefiles.a`
into `root/usr/lib/learn/morefiles/`.

Archive provenance:

* Source archive: `v7/usr/lib/learn/morefiles.a`
* Source archive size: 73,294 bytes
* Extracted members: 45
* Extracted payload: 72,093 bytes
* Installed path: `/usr/lib/learn/morefiles`

Exact wiring diffs for this slice:

```diff
--- Makefile
+++ Makefile
@@
+LEARN_MOREFILE_NAMES = L0 L0.1a L0.1b ... L6.2e L7.1a
+LEARN_MOREFILES = $(addprefix root/usr/lib/learn/morefiles/,$(LEARN_MOREFILE_NAMES))
@@
-	root/usr/lib/learn/Linfo root/usr/lib/learn/Xinfo $(LEARN_FILES) \
+	root/usr/lib/learn/Linfo root/usr/lib/learn/Xinfo $(LEARN_FILES) $(LEARN_MOREFILES) \
@@
-root.img: ... tools/extract-old-ar.py $(LEARN_FILES) build/auxfs.img
+root.img: ... tools/extract-old-ar.py $(LEARN_FILES) $(LEARN_MOREFILES) build/auxfs.img
@@
+$(LEARN_MOREFILES): v7/usr/lib/learn/morefiles.a tools/extract-old-ar.py
+	mkdir -p root/usr/lib/learn/morefiles
+	python3 tools/extract-old-ar.py v7/usr/lib/learn/morefiles.a root/usr/lib/learn/morefiles
--- conf/qemu_arm/root.proto
+++ conf/qemu_arm/root.proto
@@
 				files	d--755 0 0
 					...
 					$
+				morefiles	d--755 0 0
+					L0	---644 0 0 root/usr/lib/learn/morefiles/L0
+					...
+					L7.1a	---644 0 0 root/usr/lib/learn/morefiles/L7.1a
+					$
```

Build and QEMU evidence are recorded in `logs/unix-on-qemu.md` under
`LEARN_MOREFILES`.

No `editor`, `C`, `eqn`, `macros`, `games/chess`, toolchain,
troff/doc, network/mail/uucp, or standalone material was ported or
wired by this slice.
