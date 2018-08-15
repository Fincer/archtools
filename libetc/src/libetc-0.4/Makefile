VERSION = 0.4
MAJOR = 0

LIBDIR=/usr/lib

.PHONY: all
all: libetc.so.${VERSION}

libetc.so.${VERSION}: libetc.c libetc.h
	gcc ${CFLAGS} -Wall -g -O2 -shared -fPIC -Wl,-soname,libetc.so.${MAJOR} -o libetc.so.${VERSION} libetc.c -ldl -lc

.PHONY: clean
clean:
	rm -f libetc.so.${VERSION}

.PHONY: all
install: libetc.so.${VERSION}
	install -s -m 6644 libetc.so.${VERSION} ${DESTDIR}${LIBDIR}
	ln -fs ${DESTDIR}${LIBDIR}/libetc.so.${VERSION} ${DESTDIR}${LIBDIR}/libetc.so.${MAJOR}
	ln -fs ${DESTDIR}${LIBDIR}/libetc.so.${VERSION} ${DESTDIR}${LIBDIR}/libetc.so
