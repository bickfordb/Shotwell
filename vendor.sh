#!/bin/bash

set -e
x=$(dirname -- $0)
projectroot=$(cd $x; echo $PWD)
BUILDROOT=$projectroot/build

mkdir -p ${BUILDROOT}
mkdir -p ${BUILDROOT}/vendor \
    ${BUILDROOT}/vendor/bin \
    ${BUILDROOT}/vendor/lib \

export CFLAGS="-O0 -ggdb ${CFLAGS}"
export CPPFLAGS="-I${BUILDROOT}/vendor/include"
export LDFLAGS="-L${BUILDROOT}/vendor/lib"
export PATH="${BUILDROOT}/vendor/bin:$PATH"

if [ ! -e "${BUILDROOT}/zlib.stamp" ];
then
    echo "building zlib"
    cd vendor/zlib-1.2.6
    ./configure --prefix=${BUILDROOT}/vendor --static
    make clean
    make
    make install
    touch ${BUILDROOT}/zlib.stamp
fi  

if [ ! -e "${BUILDROOT}/openssl.stamp" ];
then
    echo "building openssl"
    cd $projectroot/vendor/openssl-1.0.0g
    ./Configure --prefix=${BUILDROOT}/vendor --openssldir=${BUILDROOT}/vendor/openssl darwin64-x86_64-cc
    make clean
    make
    make install
    touch ${BUILDROOT}/openssl.stamp
fi  

if [ ! -e "${BUILDROOT}/sdl.stamp" ];
then
    echo "building sdl"
    cd $projectroot/vendor/SDL-1.2.15
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    make install
    touch ${BUILDROOT}/sdl.stamp
fi  

if [ ! -e "${BUILDROOT}/libav.stamp" ];
then
    echo "building libav"
    rm -rf ${BUILDROOT}/scratch
    mkdir ${BUILDROOT}/scratch
    cd ${BUILDROOT}/scratch
    tar xzvf $projectroot/vendor/libav-0.8.tar.gz
    cd libav-0.8
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make
    make install
    touch ${BUILDROOT}/libav.stamp
fi  

if [ ! -e "${BUILDROOT}/gtest.stamp" ];
then
    echo "building gtest"
    cd $projectroot/vendor/gtest-1.6.0
    ./configure --prefix=${BUILDROOT}/vendor --disable-shared
    make clean
    make
    #install $projectroot/vendor/gtest-1.6.0/lib
    #install vendor/gtest-1.6.0/lib/.libs/libgtest.a build/vendor/lib
    install $projectroot/vendor/gtest-1.6.0/lib/.libs/libgtest.a ${BUILDROOT}/vendor/lib
    install $projectroot/vendor/gtest-1.6.0/lib/.libs/libgtest_main.a ${BUILDROOT}/vendor/lib
    touch ${BUILDROOT}/gtest.stamp
fi  

if [ ! -e "${BUILDROOT}/protobuf.stamp" ];
then
    echo "building protocol buffers"
    cd $projectroot/vendor/protobuf-2.4.1
    export CXXFLAGS=-g
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
    tar xzvf $projectroot/vendor/pcre-8.30.tar.gz
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
    tar xzvf $projectroot/vendor/leveldb-239ac9d2dea.tar.gz
    cd leveldb-239ac9d2dea
    make
    mkdir -p ${BUILDROOT}/vendor/include/leveldb
    install include/leveldb/*.h ${BUILDROOT}/vendor/include/leveldb
    install libleveldb.a ${BUILDROOT}/vendor/lib
    touch ${BUILDROOT}/leveldb.stamp
fi  

if [ ! -e "${BUILDROOT}/libevent.stamp" ]
then
  echo "Building libevent" 
  rm -rf ${BUILDROOT}/scratch
  mkdir -p ${BUILDROOT}/scratch
  cd ${BUILDROOT}/scratch

  tar xzvf ${projectroot}/vendor/libevent-2.0.17-stable.tar.gz
  cd libevent-2.0.17
  ./configure --disable-shared --prefix=${BUILDROOT}/vendor
  make
  make install
  rm -rf ${BUILDROOT}/scratch
  touch ${BUILDROOT}/libevent.stamp
fi

if [ ! -e "${BUILDROOT}/jansson.stamp" ]
then
  echo "Building jansson" 
  rm -rf ${BUILDROOT}/scratch
  mkdir -p ${BUILDROOT}/scratch
  cd ${BUILDROOT}/scratch

  tar xzvf ${projectroot}/vendor/jansson-2.3.tar.gz
  cd jansson-2.3
  ./configure --disable-shared --prefix=${BUILDROOT}/vendor
  make
  make install
  rm -rf ${BUILDROOT}/scratch
  touch ${BUILDROOT}/jansson.stamp
fi

if [ ! -e "${BUILDROOT}/icu.stamp" ]
then
  echo "Building icu" 
  rm -rf ${BUILDROOT}/scratch
  mkdir -p ${BUILDROOT}/scratch
  cd ${BUILDROOT}/scratch

  tar xzvf ${projectroot}/vendor/icu4c-4_8_1_1-src.tgz
  cd icu/source
  ./configure --disable-shared --enable-static --prefix=${BUILDROOT}/vendor --enable-rpath --disable-extras --disable-tests --disable-samples --disable-layout --disable-icuio --with-data-packaging=static
  make
  make install
  rm -rf ${BUILDROOT}/scratch
  touch ${BUILDROOT}/icu.stamp
fi

touch ${BUILDROOT}/vendor.stamp
