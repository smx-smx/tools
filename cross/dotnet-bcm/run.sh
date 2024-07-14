#!/bin/sh
ASSEMBLY=$(readlink -f "$1")
PREFIX="$(readlink -f $(dirname "$0"))"

LD_LIBRARY_PATH=$PREFIX/runtime \
MONO_PATH=$PREFIX/runtime \
$PREFIX/mono-sgen $ASSEMBLY
