#pragma once
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <strings.h>
typedef unsigned char uae_u8;
typedef unsigned short uae_u16;
typedef unsigned int uae_u32;
typedef char TCHAR;
#define _T(x) x
#define _tcsicmp strcasecmp
static inline void write_log(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap);
}
