#!/bin/bash

set -e

MYSQL_VERSION=$1
OPENSSL_VERSION=1_1_1h
ROOT=$(cd "$(dirname "$0")" && pwd)
: "${RUNNER_TEMP:=$ROOT/working}"
: "${RUNNER_TOOL_CACHE:=$RUNNER_TEMP/dist}"
PREFIX=$RUNNER_TOOL_CACHE/mysql/$MYSQL_VERSION/x64

# detect the number of CPU Core
JOBS=1
if command -v sysctl > /dev/null; then
    # on macOX
    JOBS=$(sysctl -n hw.logicalcpu_max || echo "$JOBS")
fi
if command -v nproc > /dev/null; then
    # on Linux
    JOBS=$(nproc || echo "$JOBS")
fi

mkdir -p "$RUNNER_TEMP"
cd "$RUNNER_TEMP"
rm -rf ./*

# system SSL/TLS library is too old. so we use custom build.
echo "::group::download OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    curl -sSL "https://github.com/openssl/openssl/archive/OpenSSL_$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
)
echo "::endgroup::"

echo "::group::extract OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    tar zxvf openssl.tar.gz
)
echo "::endgroup::"

echo "::group::build OpenSSL"
(
    set -eux
    cd "$RUNNER_TEMP/openssl-OpenSSL_$OPENSSL_VERSION"
    ./Configure --prefix="$PREFIX" clang
    make "-j$JOBS"
    make install_sw
)
echo "::endgroup::"

echo "::group::download MySQL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    curl -sSL "https://github.com/mysql/mysql-server/archive/mysql-$MYSQL_VERSION.tar.gz" -o mysql-src.tar.gz
)
echo "::endgroup::"

echo "::group::extract MySQL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    tar zxvf mysql-src.tar.gz
)
echo "::endgroup::"

echo "::group::build MySQL"
(
    set -eux
    cd "$RUNNER_TEMP"
    mkdir build
    cd build
    CC=clang CXX=clang++ cmake "../mysql-server-mysql-$MYSQL_VERSION" \
        -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DWITH_SSL="$PREFIX"
    make "-j$JOBS"
)
echo "::endgroup::"

echo "::group::install"
(
    set -eux
    cd "$RUNNER_TEMP/build"
    make install
)
echo "::endgroup::"

# archive
echo "::group::archive"
(
    set -eux
    cd "$PREFIX"
    tar vczf "$RUNNER_TEMP/mysql.tar.gz" .
)
echo "::endgroup::"
