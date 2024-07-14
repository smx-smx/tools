#!/usr/bin/env bash
##
## This script creates a C cross compiler toolchain for QNX
## NOTE: cross compiling libstdc++ isn't yet supported, therefore it's a C-only toolchain
## Author: Stefano Moioli <smxdev4@gmail.com>
##
set -e

## SSH password to the running QNX system
SSHPASS=root
## SSH credentials to the running QNX system
REMOTE=root@192.168.1.51
## Where to create the toolchain
PREFIX=$PWD/out

## Component versions to use
BINUTILS_VERSION="2.39"
GCC_VERSION="11.2.0"

TARGET=i386-pc-nto-qnx6.4.0


export PATH="${PREFIX}/bin:${PATH}"

download(){
	curl "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" | tar -xvJf -
	curl "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" | tar -xvJf -

	pushd gcc-${GCC_VERSION}
	patch -p1 <<"EOF"
diff -rbu gcc-11.2.0/libquadmath/printf/quadmath-printf.h a/gcc-11.2.0/libquadmath/printf/quadmath-printf.h
--- gcc-11.2.0/libquadmath/printf/quadmath-printf.h	2021-07-28 08:55:09.168313589 +0200
+++ a/gcc-11.2.0/libquadmath/printf/quadmath-printf.h	2022-09-11 18:43:07.218480573 +0200
@@ -41,6 +41,9 @@
 #ifdef HAVE_LOCALE_H
 #include <locale.h>
 #endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
 #include "quadmath-imp.h"
 #include "gmp-impl.h"
 
diff -rbu gcc-11.2.0/libquadmath/strtod/strtoflt128.c a/gcc-11.2.0/libquadmath/strtod/strtoflt128.c
--- gcc-11.2.0/libquadmath/strtod/strtoflt128.c	2021-07-28 08:55:09.172313645 +0200
+++ a/gcc-11.2.0/libquadmath/strtod/strtoflt128.c	2022-09-11 18:44:17.114793489 +0200
@@ -19,6 +19,10 @@
 /* The actual implementation for all floating point sizes is in strtod.c.
    These macros tell it to produce the `__float128' version, `strtold'.  */
 
+/** dirty workaround when cross compiling for QNX (root cause unclear) **/
+#define FLT128max FLT128_MAX
+#define FLT128min FLT128_MIN
+
 #define FLOAT		__float128
 #define FLT		FLT128
 #ifdef USE_WIDE_CHAR

EOF
	popd
}

sysroot(){
	EXTRACT="tar -C \"${PREFIX}/${TARGET}\" -xvf -"
	mkdir -p "${PREFIX}/${TARGET}" 
	(SSHPASS="$SSHPASS" sshpass -e ssh "${REMOTE}" tar -C /usr/qnx640/target/qnx6/usr -cf - include) | tar -C "${PREFIX}/${TARGET}" -xvf -
	(SSHPASS="$SSHPASS" sshpass -e ssh "${REMOTE}" tar -C /usr/qnx640/target/qnx6/x86 -cf - lib) | tar -C "${PREFIX}/${TARGET}" -xvf -
	pushd "${PREFIX}/${TARGET}"
	# the nto specfile (gcc-11.2.0/gcc/config/i386/nto.h) requires an "x86" directory
	[ -L x86 ] && rm x86
	ln -s . x86
	popd
}

binutils(){
	pushd binutils-${BINUTILS_VERSION}
	find . -type f -name "config.cache" -delete
	./configure --prefix=$PREFIX --target=$TARGET
	make -j$(nproc)
	make install
	popd
}

gcc(){
	pushd gcc-${GCC_VERSION}
	find . -type f -name "config.cache" -delete
	[ ! -d build ] && mkdir build
	pushd build
	../configure \
		--with-build-sysroot="${PREFIX}/${TARGET}/" \
		--prefix=$PREFIX \
		--target=$TARGET \
		--enable-languages=c \
		--disable-bootstrap
	make -j$(nproc)
	make install
	popd
	popd

	# workaround the "x86" directory by always appending --sysroot in a wrapper
	rm "${PREFIX}/bin/${TARGET}-gcc"
	cat <<-EOF > "${PREFIX}/bin/${TARGET}-gcc"
	#!/usr/bin/env sh
	self="\$(dirname "\$0")/${TARGET}-gcc-${GCC_VERSION}"
	sysroot="\$(dirname "\$0")/../${TARGET}/"
	"\${self}" --sysroot "\${sysroot}" "\$@"
	
	EOF
	chmod +x "${PREFIX}/bin/${TARGET}-gcc"
}

case "$1" in
	download) download;;
	sysroot) sysroot;;
	binutils) binutils;;
	gcc) gcc;;
	*)
		download
		sysroot
		binutils
		gcc
		;;
esac

