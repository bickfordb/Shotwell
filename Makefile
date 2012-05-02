all:
	@echo Targets:
	@echo "\trun  -- Run the application (w/o gdb)"
	@echo "\tgdb  -- Run the application (w/ gdb)"
	@echo "\tgdb-memory -- Run the application (w/ gdb) w/ malloc checking hooks turned on"
	@echo "\tdist -- Prepare a DMG"
	@echo "\tclean -- Clean everything"
	@echo "\tclean-fast -- Clean everything except for vendor dependencies"

APPNAME ?= Mariposa
BUILD ?= build
APP_DIR = $(BUILD)/$(APPNAME).app
IBTOOL ?= ibtool
DIST ?= dist

PROG = $(APP_DIR)/Contents/MacOS/$(APPNAME)

CXX = clang
VENDOR = $(BUILD)/vendor.stamp
CXXFLAGS += -iquote src
CXXFLAGS += -Werror
CXXFLAGS += -ferror-limit=2
CXXFLAGS += -I$(BUILD)/vendor/include
CXXFLAGS += -ggdb 
CXXFLAGS += -O0
LDFLAGS += -L$(BUILD)/vendor/lib
LDFLAGS += -lleveldb
LDFLAGS += -ljansson
LDFLAGS += -levent
LDFLAGS += -levent_pthreads
LDFLAGS += -lstdc++
LDFLAGS += -lpthread
LDFLAGS += -licuuc
LDFLAGS += -licudata
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
LDFLAGS += -framework QuartzCore 
LDFLAGS += -framework CoreServices 
LDFLAGS += -framework CoreFoundation 
LDFLAGS += -framework Foundation 
LDFLAGS += -framework IOKit 
LDFLAGS += -framework JavaScriptCore 
LDFLAGS += -framework QuartzCore
LDFLAGS += -framework VideoDecodeAcceleration 
LDFLAGS += -framework WebKit 

RESOURCES_DIR := $(APP_DIR)/Contents/Resources


SRC_RES := src/Resources
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf $(SRC_RES)/*.js)
#SRC_RESOURCES = $(wildcard $(SRC_RES)/**/**/**)
DST_RESOURCES := $(patsubst src/Resources/%, $(APP_DIR)/Contents/Resources/%, $(wildcard src/Resources/*.* src/Resources/**/*.* src/Resources/**/**/*.* src/Resources/**/**/**/*.* src/Resources/**/**/**/**/*.*))
OBJS := $(patsubst src/app/%, $(BUILD)/objs/%, $(patsubst %.mm, %.o, $(wildcard src/app/*.mm))) 
DEPS := $(patsubst src/app/%, $(BUILD)/deps/%, $(patsubst %.mm, %.d, $(wildcard src/app/*.mm))) 

.PHONY: program
all: program

$(RESOURCES_DIR)/%: $(SRC_RES)/%
	if [ ! -d "$<" ]; \
	then \
		mkdir -p $$(dirname $@); \
		install $< $@; \
	fi 

# Convert the XIB into a nib.
program: $(RESOURCES_DIR)/en.lproj/MainMenu.nib


$(BUILD)/objs:
	mkdir -p $(BUILD)/objs

$(BUILD)/deps: 
	mkdir -p $(BUILD)/deps


$(BUILD)/deps/%.d: src/app/%.mm $(VENDOR)
	mkdir -p $(BUILD)/deps
	$(CXX) $(CXXFLAGS) -MM $< |sed -e 's/^\([a-z0-9A-Z]\)/$(BUILD)\/objs\/\1/' >$@

# This will force the .d files to build.
-include $(DEPS)

$(BUILD)/objs/%.o: src/app/%.mm
	mkdir -p $(BUILD)/objs
	$(CXX) $(CXXFLAGS) -c -o $@ $<	

$(APP_DIR)/Contents/MacOS:
	mkdir -p $@

$(PROG): $(APP_DIR)/Contents/MacOS

$(PROG): $(OBJS) $(VENDOR) $(APPDIRS)
	$(CXX) $(OBJS) $(LDFLAGS) -o $@
program: $(PROG)

$(APP_DIR)/Contents/Info.plist: src/app/Info.plist $(APP_DIR)/Contents
	cp $< $@
program: $(APP_DIR)/Contents/Info.plist

run: program
	$(PROG)

gdb: program
	echo break malloc_error_break >$(BUILD)/gdb-commands
	echo handle SIGPIPE nostop noprint pass >$(BUILD)/gdb-commands
	echo run >>$(BUILD)/gdb-commands
	gdb -f -x $(BUILD)/gdb-commands $(PROG)

gdb-memory: program
	echo break malloc_error_break >$(BUILD)/gdb-commands
	echo run >>$(BUILD)/gdb-commands
	MallocScribbling=1 MallocGuardEdges=1 NSDebugEnabled=YES MallocStackLoggingNoCompact=YES gdb -f -x $(BUILD)/gdb-commands $(APP_DIR)/Contents/MacOS/$(APPNAME) 

%.nib: %.xib
	$(IBTOOL) --compile $@ $+

program: $(DST_RESOURCES)

clean:

.PHONY: clean

clean-app:
	rm -rf $(BUILD)/$(APPNAME).app
	rm -rf $(BUILD)/objs
	rm -rf $(BUILD)/deps
.PHONY: clean-app
clean-fast: clean-app

clean-dist:
	rm -rf $(DIST)
.PHONY: clean-dist
clean: clean-dist
clean-fast: clean-dist


clean-build:
	rm -rf $(BUILD)
.PHONY: clean-build
clean: clean-build

# build vendor libraries
$(VENDOR):
	./vendor.sh

test-gdb: $(BUILD)/test-runner
	gdb $(BUILD)/test-runner

TAGS: src/app/*.mm src/app/*.h
	#ctags -r src/app/* $$(find $(BUILD)/vendor/include)
	etags --language=objc -o TAGS src/app/*.h src/app/*.mm

cscope:
	cscope -b $$(find -E src -type f -regex '.+[.](cc|mm|m|h|c)') $$(find $(BUILD)/vendor/include -type f)

build/Mariposa.app.zip: build
	rm -f build/Mariposa.app.zip
	cd build && zip -r Mariposa.app.zip Mariposa.app/*

DIST_SUFFIX ?= $(shell /bin/date +%Y%m%d-%H%M%S)
DIST_NAME = $(APPNAME)-$(DIST_SUFFIX)
DMG = $(DIST_NAME).dmg

dist/$(DMG): program
	mkdir -p dist
	cd dist && \
		mkdir -p $(DIST_NAME) && \
		cp -r ../build/Mariposa.app $(DIST_NAME) && \
		hdiutil create $(DMG) -srcfolder $(DIST_NAME) -ov

dist: dist/$(DMG)

.PHONY: dist
