export BUILDROOT=$PROJECTROOT/vendor/build
export SCRATCH=${BUILDROOT}/scratch
export VENDOR=$PROJECTROOT/vendor
export INSTALL_PREFIX=${BUILDROOT}
export STAMP=${BUILDROOT}/stamp
export CFLAGS="-ggdb -O3 ${CFLAGS}"
export CXXFLAGS="-ggdb -O3 ${CXXFLAGS}"
export CPPFLAGS="-I${INSTALL_PREFIX}/include"
export LDFLAGS="-L${INSTALL_PREFIX}/lib"
export PATH="${INSTALL_PREFIX}/bin:$PATH"

