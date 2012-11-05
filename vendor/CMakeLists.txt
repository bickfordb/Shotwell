
set(vendorDir ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_target(
  buildVendorLibraries
  #OUTPUT ${vendorDir}/build/stamp/vendor
  COMMAND ${vendorDir}/build.sh
  WORKING_DIRECTORY ${vendorDir}
  DEPENDS ${vendorDir}/build.sh ${vendorDir}/env.sh)

