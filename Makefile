mll:
	@echo Targets:
	@echo "  run-mac  -- Run the mac application"
	@echo "  gdb  -- Run the mac application in gdb"

APPNAME = MD0
APP = build/$(APPNAME).app
BUILD = build
APPSRCS := src/md0/mac/*.m src/md0/mac/*.mm
APPHDRS := src/md0/mac/*.h
LIBSRCS := src/md0/lib/*.cc
LIBHDRS = src/md0/lib/*.h

#CXX = clan
CXX = clang
VENDOR_STAMP = $(BUILD)/vendor.stamp
#CXXFLAGS += -iquote src/md0/lib
CXXFLAGS += -iquote src
CXXFLAGS += -Werror
CXXFLAGS += -ferror-limit=2
CXXFLAGS += -Ibuild/vendor/include
LDFLAGS += -Lbuild/vendor/lib
LDFLAGS += -lleveldb
LDFLAGS += -ljansson
LDFLAGS += -levent
LDFLAGS += -lstdc++
LDFLAGS += -lpcrecpp
LDFLAGS += -lSDL
LDFLAGS += -lpcre
LDFLAGS += -lpthread
LDFLAGS += -licuuc
LDFLAGS += -licudata
LDFLAGS += -lpcrecpp 
LDFLAGS += -lavcodec
LDFLAGS += -lavdevice
CXXFLAGS += -ggdb 
CXXFLAGS += -O0 
LDFLAGS += -lavfilter
LDFLAGS += -lavformat
LDFLAGS += -lavutil
LDFLAGS += -lbz2
LDFLAGS += -lssl 
LDFLAGS += -lcrypto 
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
DST_RES := $(APP)/Contents/Resources
SRC_RES := src/md0/mac/res
#RESOURCES := src/mac/res/Play_Play.png
#RESOURCES := src/mac/res/Play_Play.png
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf)
RESOURCETARGETS := $(foreach f, $(SRC_RESOURCES), $(addprefix $(DST_RES)/, $(notdir $(f)))) 

GTEST = vendor/gtest-1.6.0
TESTCFLAGS += -iquote src/vendor/gtest-1.6.0/include 
TESTLDFLAGS += -Lsrc/vendor/gtest-1.6.0/lib -lgtest -lgtest_main
TESTSRCS +=  src/md0/test/*.cc
PROJ = $(CURDIR)
PROTOC = $(PROJ)/build/vendor/bin/protoc
PROTOSRCS = src/md0/lib/track.pb.cc src/md0/lib/track.pb.h

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

$(APP)/Contents/MacOS/MD0: $(APPSRCS) $(LIBSRCS) $(APPHDRS) $(LIBHDRS) $(VENDOR_STAMP)
	mkdir -p $(APP)/Contents/MacOS
	$(CXX) $(CXXFLAGS) $(APPSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)
mac: $(APP)/Contents/MacOS/MD0

$(APP)/Contents/Info.plist: src/md0/mac/Info.plist $(APP)/Contents
	cp $< $@
mac: $(APP)/Contents/Info.plist

run-mac: mac
	$(APP)/Contents/MacOS/$(APPNAME)

gdb: mac
	echo run >build/gdb-commands
	gdb -f -x build/gdb-commands $(APP)/Contents/MacOS/$(APPNAME) 

gdb2: mac
	gdb $(APP)/Contents/MacOS/$(APPNAME) 

$(DST_RES)/en.lproj:
	mkdir -p $@
mac: $(DST_RES)/en.lproj

$(DST_RES)/en.lproj/MainMenu.nib: $(SRC_RES)/en.lproj/MainMenu.xib 
	ibtool --compile $@ $+
mac: $(DST_RES)/en.lproj/MainMenu.nib

$(RESOURCETARGETS): $(DST_RES)/%: $(SRC_RES)/% 
	cp $< $@

mac: $(RESOURCETARGETS)

build/test-runner: $(TESTSRCS) $(LIBSRCS) $(LIBHDRS) $(VENDOR_STAMP) $(PROTOSRCS) 
	$(CXX) $(CXXFLAGS) $(TESTCFLAGS) $(LIBSRCS) $(GTESTSRCS) $(TESTSRCS) -o $@ $(LDFLAGS) $(TESTLDFLAGS)

test: build/test-runner
	build/test-runner

clean:

clean-libtest:
	rm -f build/libtest 

clean: clean-libtest

# build vendor libraries
$(VENDOR_STAMP):
	./vendor.sh

src/md0/lib/track.pb.cc src/md0/lib/track.pb.h: src/md0/lib/track.proto $(VENDOR_STAMP)
	cd src/md0/lib && $(PROTOC) --cpp_out=. track.proto 

test-gdb: build/test-runner
	gdb build/test-runner

fuzz:
	echo $(DST_RES)
	echo $(SRC_RES)
	echo $(SRC_RESOURCES)
	echo $(RESOURCETARGETS)

RAOPSRCS = src/md0/tools/raoptest.cc

raop: build/raop
	echo run >build/gdb-commands
	gdb -f -x build/gdb-commands build/raop 

build/raop: $(LIBSRCS) $(LIBHDRS) $(RAOPSRCS) $(VENDOR_STAMP) 
	$(CXX) $(CXXFLAGS) $(RAOPSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)

ALACSRCS = src/md0/test/alac.cc

build/alac: $(LIBSRCS) $(LIBHDRS) $(ALACSRCS) $(VENDOR_STAMP) 
	$(CXX) $(CXXFLAGS) $(ALACSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)

alac: build/alac
	echo run >build/gdb-commands
	gdb -f -x build/gdb-commands build/alac
	
TAGS:
	ctags src/md0/lib/* src/md0/test/* src/md0/mac/* $$(find build/vendor/include)
	
cscope:
	#echo src/md0/lib/* src/md0/test/* src/md0/mac/* $$(find build/vendor/include) >cscope.files
	cscope -b $$(find -E src -type f -regex '.+[.](cc|h|c)') $$(find build/vendor/include -type f)

