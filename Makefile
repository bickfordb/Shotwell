all:
	@echo Targets:
	@echo "\trun  -- Run the application (w/o gdb)"
	@echo "\tgdb  -- Run the application (w/ gdb)"
	@echo "\tgdb-memory -- Run the application (w/ gdb) w/ malloc checking hooks turned on"
	@echo "\tdist -- Prepare a DMG"
	@echo "\tclean -- Clean everything"
	@echo "\tclean-fast -- Clean everything except for vendor dependencies"
	@echo "\ttest -- run tests"

APPNAME ?= Shotwell
BUILD ?= build
VENDOR_BUILD ?= vendor-build
APP_DIR = $(BUILD)/$(APPNAME).app
IBTOOL ?= ibtool
DIST ?= dist
GDB ?= gdb

PROG = $(APP_DIR)/Contents/MacOS/$(APPNAME)

CXX = clang
VENDOR = $(VENDOR_BUILD)/stamp/vendor
CXXFLAGS += -iquote src
CXXFLAGS += -Werror -Wall
CXXFLAGS += -ferror-limit=2
CXXFLAGS += -I$(VENDOR_BUILD)/vendor/include
CXXFLAGS += -ggdb
CXXFLAGS += -O0
LDFLAGS += -L$(VENDOR_BUILD)/vendor/lib
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
LDFLAGS += -framework CoreFoundation
LDFLAGS += -framework CoreServices
LDFLAGS += -framework Foundation
LDFLAGS += -framework IOKit
LDFLAGS += -framework JavaScriptCore
LDFLAGS += -framework Quartz
LDFLAGS += -framework QuartzCore
LDFLAGS += -framework VideoDecodeAcceleration
LDFLAGS += -framework WebKit

RESOURCES_DIR := $(APP_DIR)/Contents/Resources
SRC_RES := src/Resources
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf $(SRC_RES)/*.js)
DST_RESOURCES := $(patsubst src/Resources/%, $(APP_DIR)/Contents/Resources/%, $(wildcard src/Resources/*.* src/Resources/**/*.* src/Resources/**/**/*.* src/Resources/**/**/**/*.* src/Resources/**/**/**/**/*.*))
OBJS := $(patsubst src/app/%, $(BUILD)/objs/app/%, $(patsubst %.mm, %.o, $(wildcard src/app/*.mm)))
TESTOBJS := $(patsubst src/test/%, $(BUILD)/objs/test/%, $(patsubst %.mm, %.o, $(wildcard src/test/*.mm)))
DEPS := $(patsubst src/app/%, $(BUILD)/deps/app/%, $(patsubst %.mm, %.d, $(wildcard src/app/*.mm)))
TESTDEPS := $(patsubst src/test/%, $(BUILD)/deps/test/%, $(patsubst %.mm, %.d, $(wildcard src/test/*.mm)))

check_dirs = $(foreach i, $1, $(shell [ -d "$1" ] || mkdir -p $1 ))
create_parent_dir = $(call check_dirs, $(dir $@))

.PHONY: program
all: program

$(RESOURCES_DIR)/%: $(SRC_RES)/%
	if [ ! -d "$<" ]; \
	then \
		[ -d "$(dir $@)" ] || mkdir -p $(dir $@); \
		install $< $@; \
	fi

# Convert the XIB into a nib.
program: $(RESOURCES_DIR)/en.lproj/MainMenu.nib

$(BUILD)/deps/%.d: src/%.mm $(VENDOR)
	$(call create_parent_dir)
	$(CXX) $(CXXFLAGS) -MM -MT $(BUILD)/objs/$*.o $< >$@

# This will force the .d files to build.
-include $(DEPS)
-include $(TESTDEPS)

$(BUILD)/objs/%.o: src/%.mm
	$(call create_parent_dir)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(PROG): $(OBJS) $(VENDOR) $(APPDIRS)
	$(call create_parent_dir)
	$(CXX) $(OBJS) $(LDFLAGS) -o $@
program: $(PROG)

$(APP_DIR)/Contents/Info.plist: src/app/Info.plist
	$(call create_parent_dir)
	cp $< $@
program: $(APP_DIR)/Contents/Info.plist

run: program
	$(PROG)

$(BUILD)/gdb-commands:
	echo break malloc_error_break >$@
	echo break objc_exception_throw >>$@
	echo handle SIGPIPE nostop noprint pass >>$@
	echo run >>$@

gdb: program $(BUILD)/gdb-commands
	$(GDB) -f -x $(BUILD)/gdb-commands $(PROG)

GDB_MEMORY_ENV += MallocScribbling=1
GDB_MEMORY_ENV += MallocGuardEdges=1
GDB_MEMORY_ENV += NSDebugEnabled=YES
GDB_MEMORY_ENV += MallocStackLoggingNoCompact=YES

gdb-memory: program $(BUILD)/gdb-commands
	$(GDB_MEMORY_ENV) $(GDB) -f -x $(BUILD)/gdb-memory-commands $(PROG)

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

build/Shotwell.app.zip: build
	rm -f build/Shotwell.app.zip
	cd build && zip -r Shotwell.app.zip Shotwell.app/*

DIST_SUFFIX ?= $(shell /bin/date +%Y%m%d-%H%M%S)
DIST_NAME = $(APPNAME)-$(DIST_SUFFIX)
DMG = $(DIST_NAME).dmg

dist/$(DMG): program
	$(call create_parent_dir)
	cd dist && \
		mkdir -p $(DIST_NAME) && \
		cp -r ../build/Shotwell.app $(DIST_NAME) && \
		hdiutil create $(DMG) -srcfolder $(DIST_NAME) -ov

test-program: build/test

test: test-program
	build/test

TEST_SRCS += vendor-build/vendor/share/gtest-1.6.0/src/gtest-all.cc
ALL_TEST_OBJS = $(TESTOBJS) $(filter-out $(BUILD)/objs/app/main.o, $(OBJS))

build/test: $(VENDOR) $(TEST_SRCS) $(ALL_TEST_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $(TEST_SRCS) $(LDFLAGS) $(ALL_TEST_OBJS)

dist: dist/$(DMG)

.PHONY: dist
