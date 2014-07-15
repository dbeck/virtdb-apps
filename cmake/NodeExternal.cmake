MESSAGE(STATUS "Integrating external Node.js sources")

SET(NODE_MODULE "3rd-party/nodejs")
SET(NODE_GIT "https://github.com/starschema/node.git")

ExternalProject_Add(
  nodejs
  TMP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wipe-me/tmp/nodejs
  STAMP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wipe-me/stamp/nodejs
  DOWNLOAD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wipe-me/download/nodejs
  GIT_REPOSITORY ${NODE_GIT}
  GIT_SUBMODULES ${NODE_MODULE}
  # GIT_TAG master
  #SOURCE_DIR
  #  ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}
  CONFIGURE_COMMAND 
    ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}/configure
    --prefix=${CMAKE_CURRENT_SOURCE_DIR}/lib/nodejs/
  PREFIX
    ${CMAKE_CURRENT_SOURCE_DIR}/${NODE_MODULE}
  BUILD_COMMAND ${CMAKE_MAKE}
  BUILD_IN_SOURCE 1
  #LOG_DOWNLOAD 1
  #LOG_UPDATE 1
)

