#!/bin/bash

set -e
x=$(dirname -- $0)
projectroot=$(cd $x; echo $PWD)
BUILDROOT=$projectroot/build

mkdir -p ${BUILDROOT}
mkdir -p ${BUILDROOT}/vendor \
    ${BUILDROOT}/vendor/bin \
    ${BUILDROOT}/vendor/lib \

export CPPFLAGS="-I${BUILDROOT}/vendor/include"
export LDFLAGS="-L${BUILDROOT}/vendor/lib"
export PATH="${BUILDROOT}/vendor/bin:$PATH"

if [ ! -e "${BUILDROOT}/zlib.stamp" ];
then
    echo "building zlib"
    cd src/vendor/zlib-1.2.6
    ./configure --prefix=${BUILDROOT}/vendor --static
    make clean
    make
    make install
    touch ${BUILDROOT}/zlib.stamp
fi  

if [ ! -e "${BUILDROOT}/openssl.stamp" ];
then
    echo "building openssl"
    cd $projectroot/src/vendor/openssl-1.0.0g
    ./Configure --prefix=${BUILDROOT}/vendor --openssldir=${BUILDROOT}/vendor/openssl darwin64-x86_64-cc
    make clean
    make
    make install
    touch ${BUILDROOT}/openssl.stamp
fi  

if [ ! -e "${BUILDROOT}/sdl.stamp" ];
then
    echo "building sdl"
    cd $projectroot/src/vendor/SDL-1.2.15
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    make install
    touch ${BUILDROOT}/sdl.stamp
fi  

if [ ! -e "${BUILDROOT}/libav.stamp" ];
then
    echo "building libav"
    cd $projectroot/src/vendor/libav-0.8
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    make install
    touch ${BUILDROOT}/libav.stamp
fi  

if [ ! -e "${BUILDROOT}/gtest.stamp" ];
then
    echo "building gtest"
    cd $projectroot/src/vendor/gtest-1.6.0
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    #install $projectroot/src/vendor/gtest-1.6.0/lib
    #install src/vendor/gtest-1.6.0/lib/.libs/libgtest.a build/vendor/lib
    install $projectroot/src/vendor/gtest-1.6.0/lib/.libs/libgtest.a ${BUILDROOT}/vendor/lib
    install $projectroot/src/vendor/gtest-1.6.0/lib/.libs/libgtest_main.a ${BUILDROOT}/vendor/lib
    touch ${BUILDROOT}/gtest.stamp
fi  

if [ ! -e "${BUILDROOT}/protobuf.stamp" ];
then
    echo "building protocol buffers"
    cd $projectroot/src/vendor/protobuf-2.4.1
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    make install
    touch ${BUILDROOT}/protobuf.stamp
fi  

if [ ! -e "${BUILDROOT}/pcre.stamp" ];
then
    echo "building pcre"
    rm -rf ${BUILDROOT}/scratch
    mkdir -p ${BUILDROOT}/scratch
    cd ${BUILDROOT}/scratch
    tar xzvf $projectroot/src/vendor/pcre-8.30.tar.gz
    cd pcre-8.30
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make
    make install
    touch ${BUILDROOT}/pcre.stamp
fi  

if [ ! -e "${BUILDROOT}/leveldb.stamp" ];
then
    echo "building leveldb"
    rm -rf ${BUILDROOT}/scratch
    mkdir -p ${BUILDROOT}/scratch
    cd ${BUILDROOT}/scratch
    tar xzvf $projectroot/src/vendor/leveldb-239ac9d2dea.tar.gz
    cd leveldb-239ac9d2dea
    make
    mkdir -p ${BUILDROOT}/vendor/include/leveldb
    install include/leveldb/*.h ${BUILDROOT}/vendor/include/leveldb
    install libleveldb.a ${BUILDROOT}/vendor/lib
    touch ${BUILDROOT}/leveldb.stamp
fi  



touch ${BUILDROOT}/vendor.stamp

