MESSAGE(STATUS "cmake configure src/interface/db_config/...")

ADD_CUSTOM_COMMAND(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/db_config.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/db_config.pb.h
  PRE_BUILD
  COMMAND
    ${PB_COMPILER}
  ARGS
    --cpp_out=${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/../common/
    ${CMAKE_CURRENT_SOURCE_DIR}/db_config.proto
  MAIN_DEPENDENCY
    ${CMAKE_CURRENT_SOURCE_DIR}/db_config.proto
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/common.proto
  WORKING_DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/
  )

INCLUDE_DIRECTORIES(
  ${CMAKE_CURRENT_SOURCE_DIR}/../common/
  )

SET(
  INTERFACE_META_DATA_SOURCES
  db_config.pb.cc
  )

ADD_LIBRARY(
  interface_db_config_obj
  OBJECT
  ${INTERFACE_META_DATA_SOURCES}
  )

ADD_LIBRARY(
  interface_db_config
  STATIC
  $<TARGET_OBJECTS:interface_db_config_obj>
  )

# SUBDIRS( xxx )

