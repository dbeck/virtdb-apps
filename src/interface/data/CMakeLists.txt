MESSAGE(STATUS "cmake configure src/interface/data/...")

ADD_CUSTOM_COMMAND(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/data.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/data.pb.h
  PRE_BUILD
  COMMAND
    ${PB_COMPILER}
  ARGS
    --cpp_out=${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/../common/
    ${CMAKE_CURRENT_SOURCE_DIR}/data.proto
  MAIN_DEPENDENCY
    ${CMAKE_CURRENT_SOURCE_DIR}/data.proto
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/common.proto
  WORKING_DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/
  )

INCLUDE_DIRECTORIES(
  ${CMAKE_CURRENT_SOURCE_DIR}/../common/
  )

SET(
  INTERFACE_DATA_SOURCES
  data.pb.cc
  )

ADD_LIBRARY(
  interface_data_obj
  OBJECT
  ${INTERFACE_DATA_SOURCES}
  )

ADD_LIBRARY(
  interface_data
  STATIC
  $<TARGET_OBJECTS:interface_data_obj>
  )

# SUBDIRS( xxx )

