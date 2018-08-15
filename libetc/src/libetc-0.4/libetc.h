/*
 * libetc - Copyright (C) 2005-2008 Luc Dufresne <luc@ordiluc.net>
 * Copyright (C) 1991-2002, 2003, 2004 Free Software Foundation, Inc
 * 
 * code pasted from various glibc include files 
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


struct stat
{
        __dev_t st_dev;                     /* Device.  */
        unsigned short int __pad1;
#ifndef __USE_FILE_OFFSET64
        __ino_t st_ino;                     /* File serial number.  */
#else
        __ino_t __st_ino;                   /* 32bit file serial number.    */
#endif
        __mode_t st_mode;                   /* File mode.  */
        __nlink_t st_nlink;                 /* Link count.  */
        __uid_t st_uid;                     /* User ID of the file's owner. */
        __gid_t st_gid;                     /* Group ID of the file's group.*/
        __dev_t st_rdev;                    /* Device number, if device.  */
        unsigned short int __pad2; 
#ifndef __USE_FILE_OFFSET64
        __off_t st_size;                    /* Size of file, in bytes.  */
#else
        __off64_t st_size;                  /* Size of file, in bytes.  */
#endif
        __blksize_t st_blksize;             /* Optimal block size for I/O.  */

#ifndef __USE_FILE_OFFSET64
        __blkcnt_t st_blocks;               /* Number 512-byte blocks allocated. */ 
#else
        __blkcnt64_t st_blocks;             /* Number 512-byte blocks allocated. */ 
#endif
#ifdef __USE_MISC
        /* Nanosecond resolution timestamps are stored in a format
           equivalent to 'struct timespec'.  This is the type used
           whenever possible but the Unix namespace rules do not allow the
           identifier 'timespec' to appear in the <sys/stat.h> header.
           Therefore we have to handle the use of this header in strictly
           standard-compliant sources special.  */
        struct timespec st_atim;            /* Time of last access.  */
        struct timespec st_mtim;            /* Time of last modification.  */
        struct timespec st_ctim;            /* Time of last status change.  */
# define st_atime st_atim.tv_sec        /* Backward compatibility.  */
# define st_mtime st_mtim.tv_sec
# define st_ctime st_ctim.tv_sec                                                #else                                                                                   __time_t st_atime;                  /* Time of last access.  */                 unsigned long int st_atimensec;     /* Nscecs of last access.  */               __time_t st_mtime;                  /* Time of last modification.  */           unsigned long int st_mtimensec;     /* Nsecs of last modification.  */          __time_t st_ctime;                  /* Time of last status change.  */
        unsigned long int st_ctimensec;     /* Nsecs of last status change.  */
#endif
#ifndef __USE_FILE_OFFSET64
        unsigned long int __unused4;
        unsigned long int __unused5;
#else
        __ino64_t st_ino;                   /* File serial number.  */
#endif
};

struct stat64 {
};

#if __WORDSIZE == 32
# define _STAT_VER 3
#else
#define _STAT_VER 1
#endif

#define __S_ISTYPE(mode, mask)  (((mode) & __S_IFMT) == (mask))
#define __S_IFMT        0170000 /* These bits determine file type.  */
#define __S_IFDIR       0040000 /* Directory.  */
#define S_ISDIR(mode)    __S_ISTYPE((mode), __S_IFDIR)

struct utimbuf {
};

extern char *getenv (__const char *__name) __THROW __nonnull ((1));
extern void exit (int __status) __THROW __attribute__ ((__noreturn__));
extern void free (void *__ptr) __THROW;
extern char *get_current_dir_name(void);

/* Taken from GMP :) */
#ifndef LIKELY

#if defined (__GNUC__) && defined (__GNUC_MINOR__)
#define __GNUC_PREREQ(maj, min) \
  ((__GNUC__ << 16) + __GNUC_MINOR__ >= ((maj) << 16) + (min))
#else
#define __GNUC_PREREQ(maj, min)  0
#endif

#if __GNUC_PREREQ (3,0)
#define LIKELY(cond)    __builtin_expect ((cond) != 0, 1)
#define UNLIKELY(cond)  __builtin_expect ((cond) != 0, 0)
#else
#define LIKELY(cond)    (cond)
#define UNLIKELY(cond)  (cond)
#endif

#endif

