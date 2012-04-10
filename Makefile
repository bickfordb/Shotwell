all:
	@echo Targets:
	@echo "\trun  -- Run the application (w/o gdb)"
	@echo "\tgdb  -- Run the application (w/ gdb)"
	@echo "\tgdb-memory  -- Run the application (w/ gdb) w/ malloc checking hooks turned on"

APPNAME = MD0
APP = build/$(APPNAME).app
BUILD = build
SRCS := src/md0/*.mm
HDRS := src/md0/*.h

CXX = clang
VENDOR_STAMP = $(BUILD)/vendor.stamp
CXXFLAGS += -iquote build/vendor/share/jscocoa 
CXXFLAGS += -iquote src
CXXFLAGS += -Werror
CXXFLAGS += -ferror-limit=2
CXXFLAGS += -Ibuild/vendor/include
CXXFLAGS += -ggdb 
CXXFLAGS += -O0 
LDFLAGS += -Lbuild/vendor/lib
LDFLAGS += -lleveldb
LDFLAGS += -ljansson
LDFLAGS += -levent
LDFLAGS += -levent_pthreads
LDFLAGS += -lstdc++
LDFLAGS += -lpcrecpp
LDFLAGS += -lpcre
LDFLAGS += -lpthread
LDFLAGS += -licuuc
LDFLAGS += -licudata
LDFLAGS += -lpcrecpp 
LDFLAGS += -lavcodec
LDFLAGS += -lavdevice
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
#LDFLAGS += -framework OpenGL 
LDFLAGS += -framework VideoDecodeAcceleration 
LDFLAGS += -framework QuartzCore
LDFLAGS += -framework WebKit 
LDFLAGS += -lffi
DST_RES := $(APP)/Contents/Resources
SRC_RES := src/md0/res
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf $(SRC_RES)/*.js)
RESOURCETARGETS := $(foreach f, $(SRC_RESOURCES), $(addprefix $(DST_RES)/, $(notdir $(f)))) 

.PHONY: build

PROJ = $(CURDIR)

APPDIRS = $(APP) $(APP)/Contents/MacOS $(APP/Contents) $(APP)/Contents/Resources

$(APPDIRS): 
	mkdir -p $@


$(DST_RES)/Plugins:
	mkdir -p $@
build: $(DST_RES)/Plugins

$(DST_RES)/Plugins/Marquee:
	mkdir -p $@
build: $(DST_RES)/Plugins/Marquee

$(DST_RES)/Plugins/Marquee/main.js: $(SRC_RES)/Plugins/Marquee/main.js
	cp $+ $@
build: $(DST_RES)/Plugins/Marquee/main.js

$(DST_RES)/Plugins/Marquee/main.css: $(SRC_RES)/Plugins/Marquee/main.css
	cp $+ $@
build: $(DST_RES)/Plugins/Marquee/main.css

$(DST_RES)/Plugins/Marquee/jquery-1.7.2.min.js: $(SRC_RES)/Plugins/Marquee/jquery-1.7.2.min.js
	cp $+ $@
build: $(DST_RES)/Plugins/Marquee/jquery-1.7.2.min.js

$(DST_RES)/Plugins/Marquee/index.html: $(SRC_RES)/Plugins/Marquee/index.html
	cp $+ $@
build: $(DST_RES)/Plugins/Marquee/index.html

$(APP)/Contents/MacOS/MD0: $(SRCS) $(HDRS) $(VENDOR_STAMP) $(APPDIRS)
	$(CXX) $(CXXFLAGS) $(APPCXXFLAGS) $(SRCS) -o $@ $(LDFLAGS)
build: $(APP)/Contents/MacOS/MD0

$(APP)/Contents/Info.plist: src/md0/Info.plist $(APP)/Contents
	cp $< $@
build: $(APP)/Contents/Info.plist

run: build
	$(APP)/Contents/MacOS/$(APPNAME)

gdb: build
	echo break malloc_error_break >build/gdb-commands
	echo run >>build/gdb-commands
	gdb -f -x build/gdb-commands $(APP)/Contents/MacOS/$(APPNAME) 

gdb-memory: build
	echo run >build/gdb-commands
	MallocScribbling=1 MallocGuardEdges=1 NSDebugEnabled=YES MallocStackLoggingNoCompact=YES gdb -f -x build/gdb-commands $(APP)/Contents/MacOS/$(APPNAME) 

$(DST_RES)/en.lproj:
	mkdir -p $@
build: $(DST_RES)/en.lproj

$(DST_RES)/en.lproj/MainMenu.nib: $(SRC_RES)/en.lproj/MainMenu.xib 
	ibtool --compile $@ $+
build: $(DST_RES)/en.lproj/MainMenu.nib

$(RESOURCETARGETS): $(DST_RES)/%: $(SRC_RES)/% 
	cp $< $@

build: $(RESOURCETARGETS)


build/test-runner: $(TESTSRCS) $(LIBSRCS) $(LIBHDRS) $(VENDOR_STAMP) $(PROTOSRCS) 
	$(CXX) $(CXXFLAGS) $(TESTCFLAGS) $(LIBSRCS) $(GTESTSRCS) $(TESTSRCS) -o $@ $(LDFLAGS) $(TESTLDFLAGS)

test: build/test-runner
	build/test-runner

clean:

.PHONY: clean

clean: clean-libtest

# build vendor libraries
$(VENDOR_STAMP):
	./vendor.sh

test-gdb: build/test-runner
	gdb build/test-runner

TAGS:
	ctags -r src/md0/* $$(find build/vendor/include)
	
cscope:
	cscope -b $$(find -E src -type f -regex '.+[.](cc|mm|m|h|c)') $$(find build/vendor/include -type f)

