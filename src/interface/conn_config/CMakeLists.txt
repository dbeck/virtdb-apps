MESSAGE(STATUS "cmake configure src/interface/conn_config/...")

ADD_CUSTOM_COMMAND(
  OUTPUT
    ${CMAKE_CURRENT_SOURCE_DIR}/conn_config.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/conn_config.pb.h
  PRE_BUILD
  COMMAND
    ${PB_COMPILER}
  ARGS
    --cpp_out=${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/
    -I${CMAKE_CURRENT_SOURCE_DIR}/../common/
    ${CMAKE_CURRENT_SOURCE_DIR}/conn_config.proto
  MAIN_DEPENDENCY
    ${CMAKE_CURRENT_SOURCE_DIR}/conn_config.proto
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/common.proto
  WORKING_DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/
  )

INCLUDE_DIRECTORIES(
  ${CMAKE_CURRENT_SOURCE_DIR}/../common/
  )

SET(
  INTERFACE_CONN_CONFIG_SOURCES
  conn_config.pb.cc
  )

ADD_LIBRARY(
  interface_conn_config_obj
  OBJECT
  ${INTERFACE_CONN_CONFIG_SOURCES}
  )

ADD_LIBRARY(
  interface_conn_config
  STATIC
  $<TARGET_OBJECTS:interface_conn_config_obj>
  )

# SUBDIRS( xxx )

