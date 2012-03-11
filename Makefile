mll:
	@echo Targets:
	@echo "  run-mac  -- Run the mac application"
	@echo "  gdb  -- Run the mac application in gdb"

APPNAME = MD1
APP = build/$(APPNAME).app
BUILD = build
APPSRCS := src/mac/*.m src/mac/*.mm
APPHDRS := src/mac/*.h
LIBSRCS := src/lib/*.cc src/lib/*.c
LIBHDRS = src/lib/*.h

#CXX = clan
CXX = clang
VENDOR_STAMP = $(BUILD)/vendor.stamp
CXXFLAGS += -iquote src/lib
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
SRC_RES := src/mac/res
#RESOURCES := src/mac/res/Play_Play.png
#RESOURCES := src/mac/res/Play_Play.png
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf)
RESOURCETARGETS := $(foreach f, $(SRC_RESOURCES), $(addprefix $(DST_RES)/, $(notdir $(f)))) 

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

$(APP)/Contents/MacOS/MD1: $(APPSRCS) $(LIBSRCS) $(APPHDRS) $(LIBHDRS) $(VENDOR_STAMP)
	mkdir -p $(APP)/Contents/MacOS
	$(CXX) $(CXXFLAGS) $(APPSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)
mac: $(APP)/Contents/MacOS/MD1

$(APP)/Contents/Info.plist: src/mac/Info.plist $(APP)/Contents
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

src/lib/track.pb.cc src/lib/track.pb.h: src/lib/track.proto $(VENDOR_STAMP)
	cd src/lib && $(PROTOC) --cpp_out=. track.proto 

test-gdb: build/test-runner
	gdb build/test-runner

fuzz:
	echo $(DST_RES)
	echo $(SRC_RES)
	echo $(SRC_RESOURCES)
	echo $(RESOURCETARGETS)

RAOPSRCS = src/tools/raoptest.cc

raop: build/raop
	echo run >build/gdb-commands
	gdb -f -x build/gdb-commands build/raop 

build/raop: $(LIBSRCS) $(LIBHDRS) $(RAOPSRCS) $(VENDOR_STAMP) 
	$(CXX) $(CXXFLAGS) $(RAOPSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)

ALACSRCS = src/test/alac.cc

build/alac: $(LIBSRCS) $(LIBHDRS) $(ALACSRCS) $(VENDOR_STAMP) 
	$(CXX) $(CXXFLAGS) $(ALACSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)

alac: build/alac
	echo run >build/gdb-commands
	gdb -f -x build/gdb-commands build/alac
	
TAGS:
	ctags src/lib/* src/test/* src/mac/* $$(find build/vendor/include)
	
cscope:
	#echo src/lib/* src/test/* src/mac/* $$(find build/vendor/include) >cscope.files
	cscope -b $$(find src/lib -type f) $$(find src/test -type f) $$(find src/mac -type f) $$(find build/vendor/include -type f)

raop_play:
	cd src/pp/raop_play \
		&& make
	src/pp/raop_play/raop_play 10.0.1.10 test-data/y.pcm
	#src/pp/raop_play/raop_play 10.0.1.10 test-data/y.pcm |head -n 100 >y.log

raoptest: build/raop
	#build/raop |head -n 100 >x.log
	build/raop 


