MESSAGE(STATUS "Integrating external Node.js sources")

SET(NODE_MODULE "3rd-party/nodejs")
SET(NODE_GIT "https://github.com/starschema/node.git")

ExternalProject_Add(
  nodejs
  GIT_REPOSITORY
    ${NODE_GIT}
  GIT_SUBMODULES
    ${NODE_MODULE}
  SOURCE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}
  CONFIGURE_COMMAND 
    ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}/configure
    --prefix=${CMAKE_CURRENT_SOURCE_DIR}/lib/nodejs/
  PREFIX
    ${CMAKE_CURRENT_SOURCE_DIR}/lib/nodejs/
  BUILD_COMMAND ${CMAKE_MAKE}
  BUILD_IN_SOURCE 1
)

