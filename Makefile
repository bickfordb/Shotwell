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
LD = ld

CXX = clang
VENDOR = $(BUILD)/vendor.stamp
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
OBJS := $(patsubst src/md0/%, build/objs/%, $(patsubst %.mm, %.o, $(wildcard src/md0/*.mm))) 
DEPS := $(patsubst src/md0/%, build/deps/%, $(patsubst %.mm, %.d, $(wildcard src/md0/*.mm))) 

.PHONY: buildit
all: buildit

PROJ = $(CURDIR)

APPDIRS = $(APP) $(APP)/Contents/MacOS $(APP/Contents) $(APP)/Contents/Resources

$(APPDIRS): 
	mkdir -p $@

$(DST_RES)/Plugins:
	mkdir -p $@
buildit: $(DST_RES)/Plugins

$(DST_RES)/Plugins/Marquee:
	mkdir -p $@
buildit: $(DST_RES)/Plugins/Marquee

$(DST_RES)/Plugins/Marquee/main.js: $(SRC_RES)/Plugins/Marquee/main.js
	cp $+ $@
buildit: $(DST_RES)/Plugins/Marquee/main.js

$(DST_RES)/Plugins/Marquee/main.css: $(SRC_RES)/Plugins/Marquee/main.css
	cp $+ $@
buildit: $(DST_RES)/Plugins/Marquee/main.css

$(DST_RES)/Plugins/Marquee/jquery-1.7.2.min.js: $(SRC_RES)/Plugins/Marquee/jquery-1.7.2.min.js
	cp $+ $@
buildit: $(DST_RES)/Plugins/Marquee/jquery-1.7.2.min.js

$(DST_RES)/Plugins/Marquee/index.html: $(SRC_RES)/Plugins/Marquee/index.html
	cp $+ $@
buildit: $(DST_RES)/Plugins/Marquee/index.html

buildit: $(APP)/Contents/MacOS/MD0

build/objs:
	mkdir -p build/objs

build/deps: 
	mkdir -p build/deps

#build/objs/%.o: $(VENDOR)

build/deps/%.d: src/md0/%.mm
	mkdir -p build/deps
	$(CXX) $(CXXFLAGS) -MM $< |sed -e 's/^\([a-z0-9A-Z]\)/build\/objs\/\1/' >$@

-include $(DEPS)

build/objs/%.o: src/md0/%.mm
	mkdir -p build/objs
	$(CXX) $(CXXFLAGS) -c -o $@ $<	

$(APP)/Contents/MacOS/MD0: $(OBJS) $(HDRS) $(VENDOR) $(APPDIRS)
	$(LD) $(OBJS) /usr/lib/crt1.o $(LDFLAGS) -o $@

$(APP)/Contents/Info.plist: src/md0/Info.plist $(APP)/Contents
	cp $< $@
buildit: $(APP)/Contents/Info.plist

run: buildit
	$(APP)/Contents/MacOS/$(APPNAME)

gdb: buildit
	echo break malloc_error_break >build/gdb-commands
	echo run >>build/gdb-commands
	gdb -f -x build/gdb-commands $(APP)/Contents/MacOS/$(APPNAME) 

gdb-memory: buildit
	echo run >build/gdb-commands
	MallocScribbling=1 MallocGuardEdges=1 NSDebugEnabled=YES MallocStackLoggingNoCompact=YES gdb -f -x build/gdb-commands $(APP)/Contents/MacOS/$(APPNAME) 

$(DST_RES)/en.lproj:
	mkdir -p $@
buildit: $(DST_RES)/en.lproj

$(DST_RES)/en.lproj/MainMenu.nib: $(SRC_RES)/en.lproj/MainMenu.xib 
	ibtool --compile $@ $+
buildit: $(DST_RES)/en.lproj/MainMenu.nib

$(RESOURCETARGETS): $(DST_RES)/%: $(SRC_RES)/% 
	cp $< $@

buildit: $(RESOURCETARGETS)

build/test-runner: $(TESTSRCS) $(LIBSRCS) $(LIBHDRS) $(VENDOR) $(PROTOSRCS) 
	$(CXX) $(CXXFLAGS) $(TESTCFLAGS) $(LIBSRCS) $(GTESTSRCS) $(TESTSRCS) -o $@ $(LDFLAGS) $(TESTLDFLAGS)

test: build/test-runner
	build/test-runner

clean:
	rm -rf $(BUILD)/objs
	rm -rf $(BUILD)/deps

.PHONY: clean

#4158281448

# build vendor libraries
$(VENDOR):
	./vendor.sh

test-gdb: build/test-runner
	gdb build/test-runner

TAGS:
	ctags -r src/md0/* $$(find build/vendor/include)
	
cscope:
	cscope -b $$(find -E src -type f -regex '.+[.](cc|mm|m|h|c)') $$(find build/vendor/include -type f)

