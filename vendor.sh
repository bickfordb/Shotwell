#!/bin/bash
# Script for building vendor libraries
# This has only been tested on and is specific to OS X 10.7
# This builds vendor library specifically to not include shared libraries (.so/.dylib) so that the linker finds static libraries by default.

set -e
x=$(dirname -- $0)
projectroot=$(cd $x; echo $PWD)
BUILDROOT=$projectroot/vendor-build
SCRATCH=${BUILDROOT}/scratch
VENDOR=$projectroot/vendor
INSTALL_PREFIX=${BUILDROOT}/vendor
STAMP=${BUILDROOT}/stamp

function stamp {
  touch $STAMP/$1  
}

function scratch {
  rm -rf ${SCRATCH}
  mkdir -p ${SCRATCH}
  cd ${SCRATCH} 
}

mkdir -p \
  ${BUILDROOT} \
  ${STAMP} \
  ${INSTALL_PREFIX} \
  ${INSTALL_PREFIX}/bin \
  ${INSTALL_PREFIX}/lib \
  ${INSTALL_PREFIX}/share \
  ${INSTALL_PREFIX}/sbin

export CFLAGS="-ggdb ${CFLAGS}"
export CXXFLAGS="-ggdb ${CXXFLAGS}"
export CPPFLAGS="-I${INSTALL_PREFIX}/include"
export LDFLAGS="-L${INSTALL_PREFIX}/lib"
export PATH="${INSTALL_PREFIX}/bin:$PATH"

if [ ! -e "${STAMP}/libav" ];
then
    scratch
    tar xzvf ${VENDOR}/libav-0.8.1.tar.gz
    cd libav-0.8.1
    ./configure --prefix=${INSTALL_PREFIX} --disable-shared --enable-debug=3 --disable-optimizations
    make
    make install
    stamp libav
fi  

if [ ! -e "${STAMP}/leveldb" ];
then
    echo "building leveldb"
    scratch
    tar xzvf ${VENDOR}/leveldb-239ac9d2dea.tar.gz
    cd leveldb-239ac9d2dea
    make
    mkdir -p ${INSTALL_PREFIX}/include/leveldb
    install include/leveldb/*.h ${INSTALL_PREFIX}/include/leveldb
    install libleveldb.a ${INSTALL_PREFIX}/lib
    stamp leveldb
fi  

if [ ! -e "${STAMP}/libevent" ]
then
  scratch
  tar xzvf ${VENDOR}/libevent-2.0.17-stable.tar.gz
  cd libevent-2.0.17-stable
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  stamp libevent
fi

if [ ! -e "${STAMP}/jansson" ]
then
  scratch
  tar xzvf ${VENDOR}/jansson-2.3.tar.gz
  cd jansson-2.3
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  stamp jansson
fi

if [ ! -e "${STAMP}/icu" ]
then
  echo "Building icu" 
  scratch
  tar xzvf ${VENDOR}/icu4c-4_8_1_1-src.tgz
  cd icu/source
  ./configure --disable-shared --enable-static --prefix=${INSTALL_PREFIX} --enable-rpath --disable-extras --disable-tests --disable-samples --disable-layout --disable-icuio --with-data-packaging=static
  make
  make install
  stamp icu
fi


if [ ! -e "${STAMP}/gtest" ];
then
  scratch
  unzip ${VENDOR}/gtest-1.6.0.zip
  rm -rf ${INSTALL_PREFIX}/share/gtest-1.6.0
  mkdir -p ${INSTALL_PREFIX}/share/gtest-1.6.0
  cp -r gtest-1.6.0/src ${INSTALL_PREFIX}/share/gtest-1.6.0
  rm -rf ${INSTALL_PREFIX}/include/gtest
  cp -r gtest-1.6.0/include/gtest ${INSTALL_PREFIX}/include
  stamp gtest
fi

stamp vendor
