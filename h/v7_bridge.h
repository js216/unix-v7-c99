/*
 * v7_bridge.h -- prototypes for the cross-TU bridge between the
 * v7-side helpers in sys/v7_bridge.c (+ a few in sys/v7stubs.c)
 * and the arch/arm.c trap-dispatch path.
 *
 * Every function name starts with v7_*; the implementations live in
 * sys/v7_bridge.c except v7_namei_inum / v7_mount_init /
 * v7_inode_pack_addr / v7_inode_unpack_addr which are in
 * sys/v7stubs.c.  Both definers and the arch/arm.c caller include this
 * header so the C compiler cross-checks signatures.
 */
#ifndef V7_BRIDGE_H
#define V7_BRIDGE_H

struct inode;	/* forward-declared for v7_inode_pack/unpack_addr */

/* proc-table bookkeeping (parallel to armboot's armproc[]). */
void	v7_proc_init(void);
int	v7_proc_fork(int parent_pid, int child_pid);
void	v7_proc_exit(int curpid, int code);
void	v7_proc_reap(int pid);
int	v7_wait_check(int parent_pid, int *status);
void	v7_proc_set_current(int pid);
int	v7_get_ppid(int pid);
int	v7_proc_alive(int pid);
int	v7_proc_set_stat(int pid, int stat);
void	v7_reparent_children(int dying_pid, int new_ppid);

/* signal-pgrp helper (kbd ^C / ^\). */
void	v7_signal_pgrp(int sig, int curpid);

/* per-syscall helpers that wrap the v7 sys entry points. */
int	v7_umask_call(int *args, int kumask);
int	v7_getuid_call(int kuid);
int	v7_getgid_call(int kgid);
int	v7_getpid_call(int curpid, int ppid);
int	v7_getppid_call(int curpid);
int	v7_setuid_call(int kuid, int *args);
int	v7_setgid_call(int kgid, int *args);
int	v7_sync_call(void);
int	v7_nice_call(int *args, int curpid);
long	v7_gtime_call(void);
long	v7_stime_call(int *args);
int	v7_alarm_call(int *args, int curpid);
int	v7_pause_call(volatile unsigned int *pending_ptr);
int	v7_ftime_call(int *args);
int	v7_kill_call(int *args, int kuid, int curpid);
int	v7_signal_call(int signo, int func, int curpid);
int	v7_times_call(int *args);
int	v7_profil_call(int *args);
int	v7_lock_call(int *args, int curpid);

/* Read v7-side u.u_error (armboot's u shadow doesn't see it). */
int	v7_u_error_get(void);
/* Drop a held inode ref (back out cdir/rdir on fork failure). */
void	v7_inode_drop(void *p);

/* u-area shadow save/restore around mt_save_current / mt_load_slot. */
void	v7_u_times_save(long *out_utime, long *out_stime,
                        long *out_cutime, long *out_cstime);
void	v7_u_times_restore(long utime, long stime, long cutime, long cstime);
void	v7_u_times_snapshot(long *utp, long *stp);
void	v7_u_times_add_child(long ut, long st);
void	v7_u_signal_save(long *out_sig);
void	v7_u_signal_restore(const long *in_sig);
int	v7_save_qsav(void);
void	v7_u_qsav_save(int *dst);
void	v7_u_qsav_restore(const int *src);

/* current-dir + chroot-dir snapshot (for fork / ctx switch). */
void	*v7_cdir_save(void);
void	v7_cdir_restore(void *p);
void	*v7_rdir_save(void);
void	v7_rdir_restore(void *p);

/* path-based syscalls. */
ino_t	v7_chdir_call(char *path);
int	v7_chroot_call(char *path);
int	v7_chmod_call(char *path, int mode);
int	v7_sysacct_call(char *path);
int	v7_chown_call(char *path, int uid, int gid);
int	v7_utime_call(char *path, void *tptr);
int	v7_stat_call(char *path, void *ubuf);
int	v7_access_call(char *path, int mode);
int	v7_unlink_call(char *path);
int	v7_link_call(char *from, char *to);
int	v7_mknod_call(char *path, int mode, int dev);
int	v7_mount_call(char *special, char *dir, int ro);
int	v7_umount_call(char *special);
int	v7_exec_call(char *path, char **argv, char **envp);
int	v7_sigreturn_call(int *r);

/* fd-bound syscalls and v7 file[] mirroring. */
void	v7_ofile_set(int fd, ino_t ino, int flag);
void	v7_ofile_clear(int fd);
void	v7_ofile_dup(int from, int to);
void	v7_ofile_save(void *buf);
void	v7_ofile_restore(void *buf);
void	v7_pofile_save(void *buf);
void	v7_pofile_restore(void *buf);
void	v7_pofile_excl_set(int fd);
void	v7_pofile_excl_clear(int fd);
void	v7_ofile_fork_bump(void);
void	v7_ofile_drop_all(void);
int	v7_ofile_isset(int fd);
int	v7_fstat_call(int fd, void *ubuf);
int	v7_close_call(int fd);
int	v7_dup_call(int from, int to);
int	v7_lseek_call(int fd, int off, int whence);
int	v7_read_call(int fd, char *buf, unsigned int n);
long	v7_get_offset(int fd);
void	v7_set_offset(int fd, long off);

/* v7 in-core inode bridge (size + addr[] sync from armboot's files[]). */
void	v7_inode_refresh(int fd, unsigned int size, unsigned int *addrs);
void	v7_inode_mark_dirty(int fd);
void	v7_inode_writeback(int fd, unsigned int *size_out, unsigned int *addrs_out);
void	v7_inode_refresh_ino(ino_t ino, unsigned int size, unsigned int *addrs);
void	v7_inode_mark_dirty_ino(ino_t ino);
int	v7_inode_snapshot_ino(ino_t ino, unsigned int *size_out, unsigned int *addrs_out);
void	v7_inode_pack_addr(struct inode *ip, unsigned int *addrs);
void	v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs);

/* namei + rootfs init from sys/v7stubs.c. */
ino_t	v7_namei_inum(char *path);
int	v7_mount_init(void);

/* exec image loader (defined in arch/arm.c::kexec2). */
int	v7_load_image(char *path, char **argv, char **envp);
/* post-EXCLOSE cleanup of armboot-side fd state.  v7_exec_call calls
 * this from sys/v7_bridge.c after the v7 closef so the slot is reusable. */
void	armboot_post_exec_close(int fd);

#endif
