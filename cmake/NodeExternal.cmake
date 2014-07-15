MESSAGE(STATUS "Integrating external Node.js sources")

SET(NODE_MODULE "3rd-party/nodejs")
SET(NODE_GIT "git@github.com:starschema/node.git")

ExternalProject_Add(
  nodejs
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}/
  CONFIGURE_COMMAND 
    ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}/configure
    --prefix=${CMAKE_CURRENT_SOURCE_DIR}/lib/nodejs/
  PREFIX
    ${CMAKE_CURRENT_SOURCE_DIR}/lib/nodejs/
  BUILD_COMMAND make
  BUILD_IN_SOURCE 1
)

