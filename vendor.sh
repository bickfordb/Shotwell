#!/bin/bash
# Script for building vendor libraries
# This has only been tested on and is specific to OS X 10.7
# This builds vendor library specifically to not include shared libraries (.so/.dylib) so that the linker finds static libraries by default.

set -e
x=$(dirname -- $0)
projectroot=$(cd $x; echo $PWD)
BUILDROOT=$projectroot/build
SCRATCH=${BUILDROOT}/scratch
VENDOR=$projectroot/vendor
INSTALL_PREFIX=${BUILDROOT}/vendor
mkdir -p ${BUILDROOT}
mkdir -p ${INSTALL_PREFIX} \
    ${INSTALL_PREFIX}/bin \
    ${INSTALL_PREFIX}/lib \

export CFLAGS="-ggdb ${CFLAGS}"
export CXXFLAGS="-ggdb ${CXXFLAGS}"
export CPPFLAGS="-I${INSTALL_PREFIX}/include"
export LDFLAGS="-L${INSTALL_PREFIX}/lib"
export PATH="${INSTALL_PREFIX}/bin:$PATH"

if [ ! -e "${BUILDROOT}/libav.stamp" ];
then
    echo "building libav"
    rm -rf ${SCRATCH}
    mkdir ${SCRATCH}
    cd ${SCRATCH}
    tar xzvf ${VENDOR}/libav-0.8.1.tar.gz
    cd libav-0.8.1
    ./configure --prefix=${INSTALL_PREFIX} --disable-shared --enable-debug=3 --disable-optimizations
    make
    make install
    touch ${BUILDROOT}/libav.stamp
fi  

if [ ! -e "${BUILDROOT}/leveldb.stamp" ];
then
    echo "building leveldb"
    rm -rf ${SCRATCH}
    mkdir -p ${SCRATCH}
    cd ${SCRATCH}
    tar xzvf ${VENDOR}/leveldb-239ac9d2dea.tar.gz
    cd leveldb-239ac9d2dea
    make
    mkdir -p ${INSTALL_PREFIX}/include/leveldb
    install include/leveldb/*.h ${INSTALL_PREFIX}/include/leveldb
    install libleveldb.a ${INSTALL_PREFIX}/lib
    touch ${BUILDROOT}/leveldb.stamp
fi  

if [ ! -e "${BUILDROOT}/libevent.stamp" ]
then
  echo "Building libevent" 
  rm -rf ${SCRATCH}
  mkdir -p ${SCRATCH}
  cd ${SCRATCH}
  tar xzvf ${VENDOR}/libevent-2.0.17-stable.tar.gz
  cd libevent-2.0.17-stable
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  touch ${BUILDROOT}/libevent.stamp
fi

if [ ! -e "${BUILDROOT}/jansson.stamp" ]
then
  echo "Building jansson" 
  rm -rf ${SCRATCH}
  mkdir -p ${SCRATCH}
  cd ${SCRATCH}
  tar xzvf ${VENDOR}/jansson-2.3.tar.gz
  cd jansson-2.3
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  rm -rf ${SCRATCH}
  touch ${BUILDROOT}/jansson.stamp
fi

if [ ! -e "${BUILDROOT}/icu.stamp" ]
then
  echo "Building icu" 
  rm -rf ${SCRATCH}
  mkdir -p ${SCRATCH}
  cd ${SCRATCH}
  tar xzvf ${VENDOR}/icu4c-4_8_1_1-src.tgz
  cd icu/source
  ./configure --disable-shared --enable-static --prefix=${INSTALL_PREFIX} --enable-rpath --disable-extras --disable-tests --disable-samples --disable-layout --disable-icuio --with-data-packaging=static
  make
  make install
  touch ${BUILDROOT}/icu.stamp
fi

touch ${BUILDROOT}/vendor.stamp
