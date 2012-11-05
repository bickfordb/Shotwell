cmake_minimum_required(VERSION 2.8)
set(appName Shotwell)
project(${appName})
# Definitions
set(EXECUTABLE_OUTPUT_PATH build)
set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/src/cmake-modules ${CMAKE_MODULE_PATH})
set(vendorPrefix ${CMAKE_CURRENT_SOURCE_DIR}/vendor/build)
set(vendorLib ${vendorPrefix}/lib)
find_program(IBTOOL ibtool)

add_subdirectory(vendor)
find_library(accelerate Accelerate)
find_library(appKit AppKit)
find_library(audioToolbox AudioToolbox)
find_library(audioUnit AudioUnit)
find_library(carbon Carbon)
find_library(cocoa Cocoa)
find_library(coreAudio CoreAudio)
find_library(coreFoundation CoreFoundation)
find_library(coreServices CoreServices)
find_library(foundation Foundation)
find_library(iokit IOKit)
find_library(javascriptCore JavaScriptCore)
find_library(quartz Quartz)
find_library(quartzCore QuartzCore)
find_library(stdcpp stdc++)

find_library(videoDecodeAcceleration VideoDecodeAcceleration)
find_library(webKit WebKit)

set(systemLibs
  ${accelerate}
  ${appKit}
  ${audioToolbox}
  ${audioUnit}
  ${carbon}
  ${cocoa}
  ${coreAudio}
  ${coreFoundation}
  ${coreServices}
  ${foundation}
  ${iokit}
  ${javascriptCore}
  ${quartz}
  ${quartzCore}
  ${stdcpp}
  ${videoDecodeAcceleration}
  ${webKit}
  pthread
  bz2
  ssl
  crypto
  z)

set(vendorLibs
  ${vendorLib}/libavcodec.a
  ${vendorLib}/libavdevice.a
  ${vendorLib}/libavfilter.a
  ${vendorLib}/libavformat.a
  ${vendorLib}/libavutil.a
  ${vendorLib}/libchromaprint.a
  ${vendorLib}/libleveldb.a
  ${vendorLib}/libevent.a
  ${vendorLib}/libevent_pthreads.a
  ${vendorLib}/libprotobuf.a
  ${vendorLib}/libicuuc.a
  ${vendorLib}/libicudata.a
  ${vendorLib}/libsnappy.a
  ${vendorLib}/libswscale.a)

file(GLOB appSources src/app/*.mm src/app/pb/Track.pb.cc)
set(appSources src/app/pb/Track.pb.cc ${appSources})
file(GLOB testSources src/test/*.mm src/test/*.cc)

# Make local includes work
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -iquote ${PROJECT_SOURCE_DIR}/src")

# Resources
file(GLOB appResources
  src/assets/*.png
  src/assets/*.pdf
  src/assets/Plugins/Marquee/*.js
  src/assets/Plugins/Marquee/*.html
  src/assets/Plugins/Marquee/*.css
  src/assets/Plugins/Marquee/bootstrap-2.0.2/css/*
  src/assets/Plugins/Marquee/bootstrap-2.0.2/img/*
  src/assets/Plugins/Marquee/bootstrap-2.0.2/js/*)

foreach(f ${appResources})
  string(REPLACE "${PROJECT_SOURCE_DIR}/src/assets" "" dst ${f})
  string(REGEX REPLACE "/[^/]+$" "" dst ${dst})
  set_source_files_properties(${f} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/${dst})
endforeach(f)

# nib setup
set(nib ${EXECUTABLE_OUTPUT_PATH}/MainMenu.nib)
set(appResources ${appResources} ${nib})
set(xib ${PROJECT_SOURCE_DIR}/src/assets/en.lproj/MainMenu.xib)
add_custom_command(
  OUTPUT ${nib}
  DEPENDS ${xib}
  COMMAND ${IBTOOL} --compile ${nib} ${xib}
  COMMENT "Compiling ${xib} => ${nib}")

set_source_files_properties(${nib} PROPERTIES
  GENERATED TRUE
  MACOSX_PACKAGE_LOCATION Resources/en.lproj)

# maybe move this to the bottom?

add_executable(${appName} MACOSX_BUNDLE src/main.m ${appResources} ${appSources})
target_link_libraries(${appName} ${vendorLibs} ${systemLibs})
include_directories(${vendorPrefix}/include)

# Generate the protocol buffers:
set(ProtoC ${vendorPrefix}/bin/protoc)
add_custom_command(
  OUTPUT ${PROJECT_SOURCE_DIR}/src/app/pb/Track.pb.h ${PROJECT_SOURCE_DIR}/src/app/pb/Track.pb.cc
  WORKING_DIRECTORY src/app/pb
  COMMAND ${ProtoC} --cpp_out=. Track.proto
  DEPENDS buildVendorLibraries ${PROJECT_SOURCE_DIR}/src/app/pb/Track.proto)

set_source_files_properties(
  "${CMAKE_CURRENT_SOURCE_DIR}/src/app/pb/Track.pb.cc
  ${CMAKE_CURRENT_SOURCE_DIR}/src/app/pb/Track.pb.h"
  PROPERTIES GENERATED TRUE)

# Make sure that the vendor library step is complete before building the application
add_dependencies(${appName} BuildVendorLibraries)

# Add target to run gdb:
add_custom_target(
  gdb
  DEPENDS src/debug.gdb ${appName}
  COMMAND gdb -f -x src/debug.gdb ${EXECUTABLE_OUTPUT_PATH}/${appName}.app/Contents/MacOS/${appName})


