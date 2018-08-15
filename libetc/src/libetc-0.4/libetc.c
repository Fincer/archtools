/*
 * libetc - Copyright (C) 2005-2008 Luc Dufresne <luc@ordiluc.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * See the file COPYING
 *
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stddef.h>

#include "libetc.h"

// #define DEBUG

#ifdef DEBUG
#define PRINT_DEBUG(args...) fprintf (stderr, args)
#else
#define PRINT_DEBUG(args...)
#endif

static FILE * (*orig_fopen) (const char *path, const char *mode);
static FILE * (*orig_fopen64) (const char *path, const char *mode);
static FILE * (*orig_freopen) (const char *path, const char *mode, FILE *stream);
static FILE * (*orig_freopen64) (const char *path, const char *mode, FILE *stream);
static int (*orig_open) (const char *path, int flags, mode_t mode);
static int (*orig_open64) (const char *path, int flags, mode_t mode);
static int (*orig_mkdir) (const char *path, mode_t mode);
static int (*orig_rename) (const char *oldpath, const char *newpath);
static int (*orig_unlink) (const char *path);
static int (*orig_remove) (const char *path);
static int (*orig_link) (const char *oldpath, const char *newpath);
static int (*orig_symlink) (const char *oldpath, const char *newpath);
static DIR * (*orig_opendir) (const char *name);
static int (*orig_chdir) (const char *path);
static int (*orig___xstat) (int ver, const char *file_name, struct stat *buf);
static int (*orig___xstat64) (int ver, const char *file_name, struct stat64 *buf);
static int (*orig___lxstat) (int ver, const char *file_name, struct stat *buf);
static int (*orig___lxstat64) (int ver, const char *file_name, struct stat64 *buf);
static int (*orig_access) (const char *path, int mode);
static int (*orig_chmod) (const char *path, mode_t mode);
static int (*orig_chown) (const char *path, uid_t owner, gid_t group);
static int (*orig_lchown) (const char *path, uid_t owner, gid_t group);
static int (*orig_utime) (const char *filename, struct utimbuf *buf);
static int (*orig_utimes) (const char *filename, struct timeval *tvp);
static int (*orig_truncate) (const char *path, off_t length);
static int (*orig_truncate64) (const char *path, off_t length);
static int (*orig___xmknod) (int ver, const char *path, mode_t mode, dev_t dev);
static int (*orig_mkfifo) (const char *path, mode_t mode);
static int (*orig_creat) (const char *path, mode_t mode);
static int (*orig_creat64) (const char *path, mode_t mode);
static int (*orig_connect) (int sockfd, const struct sockaddr *serv_addr, socklen_t addrlen);
static int (*orig_bind) (int sockfd, const struct sockaddr *my_addr, socklen_t addrlen);
static int (*orig_readlink) (const char *path, char *buf, size_t bufsiz);
static int (*orig_rmdir) (const char *path);
static int (*orig_mkstemp) (char *template);
static int (*orig_mkstemp64) (char *template);

static char *ETCDIR = ".config";
static char *orig, *home, *etcdir;
static int started = 0;
static int blacklisted = 0;

// is the running exec blacklisted ?
static void am_i_blacklisted () {
	char running_exec[4096], *exec_blacklist, *str;
	int len;

	if ((len = orig_readlink ("/proc/self/exe", running_exec, sizeof (running_exec) - 1))) {
		running_exec[len] = '\0';
		PRINT_DEBUG ("running exec: %s\n", running_exec);
		if ((exec_blacklist = getenv ("LIBETC_BLACKLIST"))) {
			PRINT_DEBUG ("blacklist: %s\n", exec_blacklist);
			while ((str = strrchr (exec_blacklist, ':'))) {
				if (0 == strcmp (++str, running_exec)) {
					blacklisted = 1;
					PRINT_DEBUG ("I am blacklisted !\n");
				}
				str--;
				str[0] = '\0';
			}
			if (0 == strcmp (exec_blacklist, running_exec)) {
				blacklisted = 1;
				PRINT_DEBUG ("I am blacklisted !\n");
			}
		}
	}
}

// find where to put the dotfiles
static void find_etcdir () {
	char *etc, *xdg_config_home;

	if (!(xdg_config_home = getenv ("XDG_CONFIG_HOME"))) {
		if (!(etc = getenv ("ETC"))) {
			etc = ETCDIR;
			PRINT_DEBUG("default value: %s\n", etc);
		}
		PRINT_DEBUG("$ETC: %s\n", etc);
		etcdir = malloc (strlen (home) + strlen (etc) + 1);
		sprintf (etcdir, "%s/%s", home, etc);
	} else {
		PRINT_DEBUG("$XDG_CONFIG_HOME: %s\n", xdg_config_home);
		etcdir = xdg_config_home;
	}
}

// mkdir etcdir if it does not exist
static void mkdir_etcdir (const char* etcdir) {
	struct stat info;

	if (-1 == orig___xstat (_STAT_VER, etcdir, &info)) {
		if (orig_mkdir (etcdir, 0700)) {
			fprintf (stderr, "Unable to create config directory %s: ", etcdir);
			perror ("");
			exit (2);
		}
	} else {
		if (!S_ISDIR(info.st_mode)) {
			fprintf (stderr, "ERROR: %s exists and is not a directory\n", etcdir);
			exit (2);
		}
	}
}

#ifdef XAUTH_HACK
// ln -s $HOME/.Xauthority $XDG_CONFIG_HOME/Xauthority
static void xauthority_hack (const char* etcdir) {
	int len;
	char link_dest[4096];

	char etcxauth [strlen (etcdir) + strlen ("/Xauthority") + 1];
	sprintf (etcxauth, "%s/Xauthority", etcdir );

	char homexauth [strlen (home) + strlen ("/.Xauthority") + 1];
	sprintf (homexauth, "%s/.Xauthority", home );

	if ((len = orig_readlink (etcxauth, link_dest, sizeof (link_dest) -1))) { 
		link_dest[len] = '\0';
		if (0 == strcmp (link_dest, homexauth)) {
			PRINT_DEBUG(stderr, "$XDG_CONFIG_HOME/Xauthority link is OK\n");
			return; // the link is OK
		}
	}
	PRINT_DEBUG(stderr, "I need to recreate $XDG_CONFIG_HOME/Xauthority link\n");
	orig_unlink (etcxauth);
	orig_symlink (homexauth, etcxauth);
}
#endif // XAUTH_HACK

// called only once on program startup
static void start_up () {
	if (LIKELY (started))
		return;

	orig_fopen = dlsym (RTLD_NEXT, "fopen");	
	orig_fopen64 = dlsym (RTLD_NEXT, "fopen64");
	orig_freopen = dlsym (RTLD_NEXT, "freopen");
	orig_freopen64 = dlsym (RTLD_NEXT, "freopen64");
	orig_open = dlsym (RTLD_NEXT, "open");
	orig_open64 = dlsym (RTLD_NEXT, "open64");
	orig_mkdir = dlsym (RTLD_NEXT, "mkdir");
	orig_rename = dlsym (RTLD_NEXT, "rename");
	orig_unlink = dlsym (RTLD_NEXT, "unlink");
	orig_remove = dlsym (RTLD_NEXT, "remove");
	orig_link = dlsym (RTLD_NEXT, "link");
	orig_symlink = dlsym (RTLD_NEXT, "symlink");
	orig_opendir = dlsym (RTLD_NEXT, "opendir");
	orig_chdir = dlsym (RTLD_NEXT, "chdir");
	orig___xstat = dlsym (RTLD_NEXT, "__xstat");
	orig___xstat64 = dlsym (RTLD_NEXT, "__xstat64");
	orig___lxstat = dlsym (RTLD_NEXT, "__lxstat");
	orig___lxstat64 = dlsym (RTLD_NEXT, "__lxstat64");
	orig_access = dlsym (RTLD_NEXT, "access");
	orig_chmod = dlsym (RTLD_NEXT, "chmod");
	orig_chown = dlsym (RTLD_NEXT, "chown");
	orig_lchown = dlsym (RTLD_NEXT, "lchown");
	orig_utime = dlsym (RTLD_NEXT, "utime");
	orig_utimes = dlsym (RTLD_NEXT, "utimes");
	orig_truncate = dlsym (RTLD_NEXT, "truncate");
	orig_truncate64 = dlsym (RTLD_NEXT, "truncate64");
	orig___xmknod = dlsym (RTLD_NEXT, "__xmknod");
	orig_mkfifo = dlsym (RTLD_NEXT, "mkfifo");
	orig_creat = dlsym (RTLD_NEXT, "creat");
	orig_creat64 = dlsym (RTLD_NEXT, "creat64");
	orig_connect = dlsym (RTLD_NEXT, "connect");
	orig_bind = dlsym (RTLD_NEXT, "bind");
	orig_readlink = dlsym (RTLD_NEXT, "readlink");
	orig_rmdir = dlsym (RTLD_NEXT, "rmdir");
	orig_mkstemp = dlsym (RTLD_NEXT, "mkstemp");
	orig_mkstemp64 = dlsym (RTLD_NEXT, "mkstemp64");

	am_i_blacklisted ();

	home = getenv ("HOME");
	if (home == NULL) {
		started = 1;
		return;
	}

	orig = malloc (strlen (home) + 3);
	sprintf (orig, "%s/.", home);

	find_etcdir ();
	mkdir_etcdir (etcdir);
#ifdef XAUTH_HACK
	xauthority_hack (etcdir);
#endif

	PRINT_DEBUG("etcdir: %s\n", etcdir);
	started = 1;
}

// rename filename if it's a dotfile in $HOME
static char *translate (const char *filename) {
	char *wd, *newfilename;

	if (UNLIKELY (!started)) start_up();
	if (UNLIKELY (home == NULL)) return strdup (filename);
	if (UNLIKELY (blacklisted)) return strdup (filename);
	
	if (UNLIKELY (!filename)) {
		PRINT_DEBUG("Filename is NULL !\n");
		return NULL;
	}

	wd = get_current_dir_name ();

	if ((0 == strcmp (wd, home)) // if cwd == $HOME
	    && filename [0] == '.'   // and a dotfile
	    && (0 != strcmp (filename, "."))
	    && (0 != strncmp (filename, "./", 2))
	    && (0 != strncmp (filename, "..", 2))) {
		char tmpfilename [strlen (home) + strlen (filename) + 2];
		sprintf (tmpfilename, "%s/%s", home, filename);
		if (0 == strncmp (tmpfilename, etcdir, strlen(etcdir))) { // do not translate if trying to read/write in $XDG_CONFIG_HOME
			newfilename = strdup (filename);
		} else {
			filename++; // remove the dot
			newfilename = malloc (strlen (filename) + strlen (etcdir) + 2);
			sprintf (newfilename, "%s/%s", etcdir, filename);
			PRINT_DEBUG("RENAMED IN $HOME --> %s\n", newfilename);
		}
	} else if (0 == strncmp (filename, orig, strlen (orig)) // if file name is $HOME/.something
		   && 0!= strncmp (filename, etcdir, strlen (etcdir)) ) { // do not translate if trying to read/write in $XDG_CONFIG_HOME
		filename += strlen (home) + 2; // remove "$HOME/." from the filename
		newfilename = malloc (strlen (filename) + strlen (etcdir) + 2);
		sprintf (newfilename, "%s/%s", etcdir, filename);
		PRINT_DEBUG("RENAMED --> %s\n", newfilename);
	} else { // not a dotfile
		newfilename = strdup (filename);
	}
	
	free (wd);
	return newfilename;
}

#define REWRITE_FUNCTION_SIMPLE(return_type, function_name, signature, orig_call) \
return_type function_name signature { \
	return_type return_value; \
	char *new_path; \
	\
	PRINT_DEBUG(#function_name ": %s\n", path); \
	\
	new_path = translate (path); \
	return_value = orig_##function_name orig_call; \
	free (new_path); \
	return return_value; \
}
//#define NPATH  NEWPATH(new_path, path)

REWRITE_FUNCTION_SIMPLE(FILE*, fopen, (const char *path, const char *mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(FILE*, fopen64, (const char *path, const char *mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(FILE*, freopen, (const char *path, const char *mode, FILE *stream), (new_path, mode, stream))
REWRITE_FUNCTION_SIMPLE(FILE*, freopen64, (const char *path, const char *mode, FILE *stream), (new_path, mode, stream))
REWRITE_FUNCTION_SIMPLE(int, open, (const char *path, int flags, mode_t mode), (new_path, flags, mode))
REWRITE_FUNCTION_SIMPLE(int, open64, (const char *path, int flags, mode_t mode), (new_path, flags, mode))
REWRITE_FUNCTION_SIMPLE(int, mkdir, (const char *path, mode_t mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, unlink, (const char *path), (new_path))
REWRITE_FUNCTION_SIMPLE(int, remove, (const char *path), (new_path))
REWRITE_FUNCTION_SIMPLE(DIR*, opendir, (const char *path), (new_path))
REWRITE_FUNCTION_SIMPLE(int, chdir, (const char *path), (new_path))
REWRITE_FUNCTION_SIMPLE(int, __xstat, (int ver, const char *path, struct stat *buf), (ver, new_path, buf))
REWRITE_FUNCTION_SIMPLE(int, __xstat64, (int ver, const char *path, struct stat64 *buf), (ver, new_path, buf))
REWRITE_FUNCTION_SIMPLE(int, __lxstat, (int ver, const char *path, struct stat *buf), (ver, new_path, buf))
REWRITE_FUNCTION_SIMPLE(int, __lxstat64, (int ver, const char *path, struct stat64 *buf), (ver, new_path, buf))
REWRITE_FUNCTION_SIMPLE(int, access, (const char *path, int mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, chmod, (const char *path, mode_t mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, chown, (const char *path, uid_t owner, gid_t group), (new_path, owner, group))
REWRITE_FUNCTION_SIMPLE(int, lchown, (const char *path, uid_t owner, gid_t group), (new_path, owner, group))
REWRITE_FUNCTION_SIMPLE(int, utime, (const char *path, struct utimbuf *buf), (new_path, buf))
REWRITE_FUNCTION_SIMPLE(int, utimes, (const char *path, struct timeval *tvp), (new_path, tvp))
REWRITE_FUNCTION_SIMPLE(int, truncate, (const char *path, off_t length), (new_path, length))
REWRITE_FUNCTION_SIMPLE(int, truncate64, (const char *path, off_t length), (new_path, length))
REWRITE_FUNCTION_SIMPLE(int, __xmknod, (int ver, const char *path, mode_t mode, dev_t dev), (ver, new_path, mode, dev))
REWRITE_FUNCTION_SIMPLE(int, mkfifo, (const char *path, mode_t mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, creat, (const char *path, mode_t mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, creat64, (const char *path, mode_t mode), (new_path, mode))
REWRITE_FUNCTION_SIMPLE(int, readlink, (const char *path, char *buf, size_t bufsize), (new_path, buf, bufsize))
REWRITE_FUNCTION_SIMPLE(int, rmdir, (const char *path), (new_path))

#define REWRITE_FUNCTION_DOUBLE(return_type, function_name, signature, orig_call) \
return_type function_name signature { \
	return_type return_value; \
	char *new_path1, *new_path2; \
	\
	PRINT_DEBUG(#function_name ": %s %s\n", path1, path2); \
	\
	new_path1 = translate (path1); \
	new_path2 = translate (path2); \
	return_value = orig_##function_name orig_call; \
	free (new_path1); \
	free (new_path2); \
	return return_value; \
}

REWRITE_FUNCTION_DOUBLE(int, rename, (const char *path1, const char *path2), (new_path1, new_path2))
REWRITE_FUNCTION_DOUBLE(int, link, (const char *path1, const char *path2), (new_path1, new_path2))
REWRITE_FUNCTION_DOUBLE(int, symlink, (const char *path1, const char *path2), (new_path1, new_path2))

#define REWRITE_FUNCTION_MKSTEMP(function_name) \
int function_name(char *path) { \
	int return_value, i; \
	char *new_path; \
	size_t size, new_size; \
	\
	PRINT_DEBUG(#function_name ": %s\n", path); \
	\
	new_path = translate (path); \
	if(LIKELY(new_path != NULL)) { \
		return_value = orig_##function_name (new_path); \
		size = strlen (path); \
		new_size = strlen (new_path); \
		for (i = 0; i <= 6; i++) { \
			path[size - i] = new_path[new_size - i]; \
		} \
		free(new_path); \
		return return_value; \
	} \
	else { \
		return orig_##function_name (path); \
	} \
} \

REWRITE_FUNCTION_MKSTEMP(mkstemp);
REWRITE_FUNCTION_MKSTEMP(mkstemp64);

#define REWRITE_FUNCTION_SOCK(function_name) \
int function_name(int sockfd, const struct sockaddr *serv_addr, socklen_t addrlen) { \
	int offset; \
        struct sockaddr_un newaddr; \
        char *path, *new_path; \
	int return_value; \
	\
	if (serv_addr->sa_family == AF_LOCAL) { \
		path = ((struct sockaddr_un*)serv_addr)->sun_path; \
		offset = (path[0] == '\0'); \
		path += offset; \
		new_path = translate (path); \
		\
		PRINT_DEBUG(#function_name": %s\n", path); \
		\
		if(LIKELY(new_path != NULL)) { \
			newaddr.sun_family = AF_LOCAL; \
			newaddr.sun_path[0] = '\0'; \
			strncpy (newaddr.sun_path + offset, new_path, sizeof (newaddr.sun_path) - offset); \
			newaddr.sun_path[sizeof (newaddr.sun_path) - 1] = '\0'; \
			return_value = orig_##function_name (sockfd, (struct sockaddr*) &newaddr, \
				offsetof (struct sockaddr_un, sun_path) + strlen(new_path) + offset); \
			free (new_path); \
			return return_value; \
		} \
		else { \
			return orig_##function_name (sockfd, serv_addr, addrlen); \
		} \
	} else { \
	        if (UNLIKELY (!started)) start_up(); \
		return orig_##function_name (sockfd, serv_addr, addrlen);  \
	} \
}

REWRITE_FUNCTION_SOCK(connect);
REWRITE_FUNCTION_SOCK(bind);
