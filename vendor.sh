#!/bin/bash
# Script for building vendor libraries
# This has only been tested on and is specific to OS X 10.8
# This builds vendor library specifically to not include shared libraries (.so/.dylib) so that the linker finds static libraries by default.

set -e
x=$(dirname -- ${0})
export PROJECTROOT=$(cd $x; echo $PWD)
. ./env.sh

function is_stamped { 
  [ -e "$STAMP/$1" ];
}

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


if ! is_stamped libav 
then
    scratch
    tar xzvf ${VENDOR}/libav-0.8.1.tar.gz
    cd libav-0.8.1
    CFLAGS="-O2 -ggdb" ./configure --prefix=${INSTALL_PREFIX} --disable-shared --enable-static
    make
    make install
    stamp libav
fi  

if ! is_stamped leveldb
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

if ! is_stamped libevent
then
  scratch
  tar xzvf ${VENDOR}/libevent-2.0.17-stable.tar.gz
  cd libevent-2.0.17-stable
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  stamp libevent
fi

if ! is_stamped jansson
then
  scratch
  tar xzvf ${VENDOR}/jansson-2.3.tar.gz
  cd jansson-2.3
  ./configure --disable-shared --prefix=${INSTALL_PREFIX}
  make
  make install
  stamp jansson
fi

if ! is_stamped icu
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


if ! is_stamped gtest 
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

if ! is_stamped chromaprint0.7
then
  echo "building chromaprint"
  scratch
  tar xzvf ${VENDOR}/chromaprint-0.7.tar.gz
  pushd chromaprint-0.7
  LD_LIBRARY_PATH=${INSTALL_PREFIX}/lib:/usr/lib cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_EXAMPLES=ON \
    -DEXTRA_LIBS="-framework Accelerate -lbz2 -lz -framework Cocoa -framework CoreServices -framework VideoDecodeAcceleration -framework QuartzCore -framework Quartz -L/usr/lib -L/usr/local/lib" \
    . 
  make 
  make install
  popd
  stamp chromaprint0.7
fi

if ! is_stamped protobuf
then
  echo building protobuf
  scratch
  tar xjvf ${VENDOR}/protobuf-2.4.1.tar.bz2
  pushd protobuf-2.4.1
  ./configure --prefix ${INSTALL_PREFIX} --enable-static --disable-shared
  make
  make install
  popd
  stamp protobuf
fi

if ! is_stamped curl
then
  echo building curl
  scratch
  tar xjvf ${VENDOR}/curl-7.28.0.tar.gz
  pushd curl-7.28.0
  ./configure --prefix=${INSTALL_PREFIX} --disable-shared --enable-static
  make
  make install
  popd
  stamp curl
fi

stamp vendor

