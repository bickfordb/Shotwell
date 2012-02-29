all:
	@echo Targets:
	@echo "  run-mac  -- Run the mac application"

APPNAME = MD1
APP = build/$(APPNAME).app
APPSRCS := src/mac/*.m src/mac/*.mm
APPHDRS := src/mac/*.h
LIBSRCS := src/lib/*.cc
LIBHDRS = src/lib/*.h
RESOURCES=
RESOURCETARGETS=$(patsubst src/mac/res/%,$(APP)/Contents/Resources/%, $(RESOURCES))
CXX = g++
CXXFLAGS += -iquote src/lib
CXXFLAGS += -Werror
CXXFLAGS += -Ibuild/vendor/include
LDFLAGS += -Lbuild/vendor/lib
LDFLAGS += -lleveldb
LDFLAGS += -lSDL
LDFLAGS += -lpcre
LDFLAGS += -lpthread
LDFLAGS += -lavcodec
LDFLAGS += -lavdevice
LDFLAGS += -ggdb 
#LDFLAGS += -O2
LDFLAGS += -lavfilter
LDFLAGS += -lavformat
LDFLAGS += -lavutil
LDFLAGS += -lbz2
LDFLAGS += -lssl 
LDFLAGS += -lswscale 
LDFLAGS += -lz 
LDFLAGS += -framework AppKit 
LDFLAGS += -framework AudioUnit 
LDFLAGS += -framework Carbon 
LDFLAGS += -framework Cocoa 
LDFLAGS += -framework CoreAudio 
LDFLAGS += -framework CoreServices 
LDFLAGS += -framework CoreFoundation 
LDFLAGS += -framework Foundation 
LDFLAGS += -framework IOKit 
LDFLAGS += -framework OpenGL 
LDFLAGS += -framework VideoDecodeAcceleration 
LDFLAGS += -framework QuartzCore
LDFLAGS += -lprotobuf
DST_RES = $(APP)/Contents/Resources
SRC_RES = src/mac/res
GTEST = src/vendor/gtest-1.6.0
TESTCFLAGS += -iquote src/vendor/gtest-1.6.0/include 
TESTLDFLAGS += -Lsrc/vendor/gtest-1.6.0/lib -lgtest -lgtest_main
TESTSRCS +=  src/test/*.cc
PROJ = $(CURDIR)
PROTOC = $(PROJ)/build/vendor/bin/protoc
PROTOSRCS = src/lib/track.pb.cc src/lib/track.pb.h

$(APP):
	mkdir -p $(APP)
	mkdir -p $(APP)/Contents
	mkdir -p $(APP)/Contents/MacOS

$(APP)/Contents:  
	mkdir -p $@
mac: $(APP)/Contents

$(APP)/Contents/Resources:  
	mkdir -p $@
mac: $(APP)/Contents/Resources

$(APP)/Contents/MacOS:  
	mkdir -p $@
mac: $(APP)/Contents/MacOS


$(APP)/Contents/MacOS/MD1: $(APP) $(APPSRCS) $(LIBSRCS) $(APPHDRS) $(LIBHDRS)
	mkdir -p $(APP)/Contents/MacOS
	$(CXX) $(CXXFLAGS) $(APPSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)
mac: $(APP)/Contents/MacOS/MD1

$(APP)/Contents/Info.plist: src/mac/Info.plist $(APP)/Contents
	cp $< $@
mac: $(APP)/Contents/Info.plist

run-mac: mac
	$(APP)/Contents/MacOS/$(APPNAME)

gdb-mac: mac
	gdb $(APP)/Contents/MacOS/$(APPNAME) 

$(DST_RES)/en.lproj:
	mkdir -p $@
mac: $(DST_RES)/en.lproj

$(DST_RES)/en.lproj/MainMenu.nib: $(SRC_RES)/en.lproj/MainMenu.xib 
	ibtool --compile $@ $+
mac: $(DST_RES)/en.lproj/MainMenu.nib

build/test-runner: $(TESTSRCS) $(LIBSRCS) $(LIBHDRS) vendor $(PROTOSRCS)
	$(CXX) $(CXXFLAGS) $(TESTCFLAGS) $(LIBSRCS) $(GTESTSRCS) $(TESTSRCS) -o $@ $(LDFLAGS) $(TESTLDFLAGS)

test: build/test-runner
	build/test-runner

clean:

clean-libtest:
	rm -f build/libtest 

clean: clean-libtest

# check vendor libraries
vendor: 
	./vendor.sh
.PHONY: vendor

src/lib/track.pb.cc src/lib/track.pb.h: src/lib/track.proto vendor
	cd src/lib && $(PROTOC) --cpp_out=. track.proto 

test-gdb: build/test-runner
	gdb build/test-runner

