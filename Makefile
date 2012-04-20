all:
	@echo Targets:
	@echo "\trun  -- Run the application (w/o gdb)"
	@echo "\tgdb  -- Run the application (w/ gdb)"
	@echo "\tgdb-memory  -- Run the application (w/ gdb) w/ malloc checking hooks turned on"

APPNAME = MD0
BUILD = build
APP_DIR = $(BUILD)/$(APPNAME).app
IBTOOL ?= ibtool

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
LDFLAGS += -lpcrecpp
LDFLAGS += -lpcre
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
LDFLAGS += -framework CoreServices 
LDFLAGS += -framework CoreFoundation 
LDFLAGS += -framework Foundation 
LDFLAGS += -framework JavaScriptCore 
LDFLAGS += -framework IOKit 
#LDFLAGS += -framework OpenGL 
LDFLAGS += -framework VideoDecodeAcceleration 
LDFLAGS += -framework QuartzCore
LDFLAGS += -framework WebKit 
#LDFLAGS += -lffi

RESOURCES_DIR := $(APP_DIR)/Contents/Resources


SRC_RES := src/Resources
SRC_RESOURCES = $(wildcard $(SRC_RES)/*.png $(SRC_RES)/*.pdf $(SRC_RES)/*.js)
#SRC_RESOURCES = $(wildcard $(SRC_RES)/**/**/**)
DST_RESOURCES := $(patsubst src/Resources/%, $(APP_DIR)/Contents/Resources/%, $(wildcard src/Resources/*.* src/Resources/**/*.* src/Resources/**/**/*.* src/Resources/**/**/**/*.* src/Resources/**/**/**/**/*.*))
OBJS := $(patsubst src/md0/%, $(BUILD)/objs/%, $(patsubst %.mm, %.o, $(wildcard src/md0/*.mm))) 
DEPS := $(patsubst src/md0/%, $(BUILD)/deps/%, $(patsubst %.mm, %.d, $(wildcard src/md0/*.mm))) 

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

$(BUILD)/deps/%.d: src/md0/%.mm
	mkdir -p $(BUILD)/deps
	$(CXX) $(CXXFLAGS) -MM $< |sed -e 's/^\([a-z0-9A-Z]\)/$(BUILD)\/objs\/\1/' >$@

# This will force the .d files to build.
-include $(DEPS)

$(BUILD)/objs/%.o: src/md0/%.mm
	mkdir -p $(BUILD)/objs
	$(CXX) $(CXXFLAGS) -c -o $@ $<	

$(APP_DIR)/Contents/MacOS:
	mkdir -p $@

$(PROG): $(APP_DIR)/Contents/MacOS

$(PROG): $(OBJS) $(VENDOR) $(APPDIRS)
	$(CXX) $(OBJS) $(LDFLAGS) -o $@
program: $(PROG)

$(APP_DIR)/Contents/Info.plist: src/md0/Info.plist $(APP_DIR)/Contents
	cp $< $@
program: $(APP_DIR)/Contents/Info.plist

run: program
	$(PROG)

gdb: program
	echo break malloc_error_break >$(BUILD)/gdb-commands
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
	rm -rf $(BUILD)/$(APPNAME).app
	rm -rf $(BUILD)/objs
	rm -rf $(BUILD)/deps
.PHONY: clean

# build vendor libraries
$(VENDOR):
	./vendor.sh

test-gdb: $(BUILD)/test-runner
	gdb $(BUILD)/test-runner

TAGS:
	ctags -r src/md0/* $$(find $(BUILD)/vendor/include)
	
cscope:
	cscope -b $$(find -E src -type f -regex '.+[.](cc|mm|m|h|c)') $$(find $(BUILD)/vendor/include -type f)

