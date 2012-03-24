mll:
	@echo Targets:
	@echo "  run-mac  -- Run the mac application"
	@echo "  gdb  -- Run the mac application in gdb"

APPNAME = MD0
APP = build/$(APPNAME).app
BUILD = build
APPSRCS := src/md0/mac/*.m src/md0/mac/*.mm  
APPEXTSRCS := build/vendor/share/jscocoa/*.m
APPHDRS := src/md0/mac/*.h
LIBSRCS := src/md0/lib/*.cc
LIBHDRS = src/md0/lib/*.h

#CXX = clan
CXX = clang
VENDOR_STAMP = $(BUILD)/vendor.stamp
#CXXFLAGS += -iquote src/md0/lib
APPCXXFLAGS += -iquote build/vendor/share/jscocoa 
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
LDFLAGS += -framework JavaScriptCore 
LDFLAGS += -framework IOKit 
LDFLAGS += -framework OpenGL 
LDFLAGS += -framework VideoDecodeAcceleration 
LDFLAGS += -framework QuartzCore
LDFLAGS += -framework WebKit 
LDFLAGS += -lprotobuf
LDFLAGS += -lffi
DST_RES := $(APP)/Contents/Resources
SRC_RES := src/md0/mac/res
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf $(SRC_RES)/*.js)
RESOURCETARGETS := $(foreach f, $(SRC_RESOURCES), $(addprefix $(DST_RES)/, $(notdir $(f)))) 

TESTLDFLAGS += -lgtest -lgtest_main
TESTSRCS +=  src/md0/test/*.cc
PROJ = $(CURDIR)
PROTOC = $(PROJ)/build/vendor/bin/protoc
PROTOSRCS = src/md0/lib/track.pb.cc src/md0/lib/plugin.pb.cc


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

$(APP)/Contents/MacOS/MD0: $(APPSRCS) $(LIBSRCS) $(APPHDRS) $(LIBHDRS) $(VENDOR_STAMP) $(PROTOSRCS)
	mkdir -p $(APP)/Contents/MacOS
	$(CXX) $(CXXFLAGS) $(APPCXXFLAGS) $(APPSRCS) $(APPEXTSRCS) $(LIBSRCS) -o $@ $(LDFLAGS)
mac: $(APP)/Contents/MacOS/MD0

$(APP)/Contents/Info.plist: src/md0/mac/Info.plist $(APP)/Contents
	cp $< $@
mac: $(APP)/Contents/Info.plist

run-mac: mac
	$(APP)/Contents/MacOS/$(APPNAME)

gdb: mac
	echo $(APPPCH)
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

.PHONY: clean

clean-libtest:
	rm -f build/libtest 

clean: clean-libtest

clean-pch:
	rm -f src/md0/**/*.h.pch
.PHONY: clean-pch

clean: clean-pch

# build vendor libraries
$(VENDOR_STAMP):
	./vendor.sh

src/md0/lib/%.pb.cc: src/md0/lib/%.proto
	cd src/md0/lib && $(PROTOC) --cpp_out=. $$(basename $+)

test-gdb: build/test-runner
	gdb build/test-runner

TAGS:
	ctags src/md0/lib/* src/md0/test/* src/md0/mac/* $$(find build/vendor/include)
	
cscope:
	cscope -b $$(find -E src -type f -regex '.+[.](cc|mm|h|c)') $$(find build/vendor/include -type f)

