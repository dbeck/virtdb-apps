MESSAGE(STATUS "cmake configure 3rd-party/...")

MESSAGE(STATUS "Integrating external Node.js sources")

# step #0 : creating a temp file so cmake won't bark at config step
FILE(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/nodejs/fake-file-for-cmake "fooling you my friend")

# step #3 : ./configure && make
ExternalProject_Add(
  nodejs
  TMP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../wipe-me/tmp/nodejs
  STAMP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../wipe-me/stamp/nodejs
  DOWNLOAD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../wipe-me/download/nodejs
  SOURCE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/nodejs
  CONFIGURE_COMMAND 
    ${CMAKE_CURRENT_SOURCE_DIR}/nodejs/configure
    --prefix=${CMAKE_CURRENT_SOURCE_DIR}/../
  PREFIX
    ${CMAKE_CURRENT_SOURCE_DIR}/nodejs
  BUILD_COMMAND ${CMAKE_MAKE}
  BUILD_IN_SOURCE 1
)

# step #1 : removing the temp file so git won't bark either
ExternalProject_Add_Step(
  nodejs nodejs-remove-fake-file 
  COMMAND rm -f ${CMAKE_CURRENT_SOURCE_DIR}/nodejs/fake-file-for-cmake
  COMMENT "removing cmake's fake file"
  # DEPENDERS nodejs-submodule 
  # DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/nodejs/fake-file-for-cmake
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  )

# step #2 : git submodule upate
ExternalProject_Add_Step(
  nodejs nodejs-submodule 
  COMMAND git submodule update --init
  COMMENT "updating git submodules"
  DEPENDEES nodejs-remove-fake-file
  # DEPENDERS nodejs  
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../.gitmodules
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../
  )

# step #4 : install node-gyp
ExternalProject_Add_Step(
  nodejs nodejs-gyp
  COMMAND ./npm install node-gyp
  COMMENT "install node-gyp"
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../bin/
  )

SUBDIRS( gtest-1.7.0 )
