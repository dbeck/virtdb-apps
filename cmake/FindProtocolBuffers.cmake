MESSAGE(STATUS "Detecting Google protocol buffers")

pkg_check_modules(PC_PBLITE QUIET protobuf-lite)
pkg_check_modules(PC_PB QUIET protobuf)
 
FIND_PATH(PB_INCLUDE google/protobuf/wire_format.h google/protobuf/repeated_field.h
  PATHS 
    ${PC_PB_INCLUDEDIR}
    ${PC_PB_INCLUDE_DIRS}
    $ENV{PB_PREFIX}/include
    $ENV{PB_INCLUDE}
    ${PC_PBLITE_INCLUDEDIR}
    ${PC_PBLITE_INCLUDE_DIRS}
    $ENV{PBLITE_PREFIX}/include
    $ENV{PBLITE_INCLUDE}
    /usr/local/include
    /usr/include
    /sw/include
    /opt/local/include
    /opt/include )

FIND_LIBRARY(PB_LIBRARY_STATIC
  NAMES
    protobuf.a
    libprotobuf.a
  PATH_SUFFIXES
    lib64
    lib
  PATHS
    ${PC_PB_LIBDIR}
    ${PC_PB_LIBRARY_DIRS}
    $ENV{PB_PREFIX}
    ${PC_PBLITE_LIBDIR}
    ${PC_PBLITE_LIBRARY_DIRS}
    $ENV{PBLITE_PREFIX}
    /usr/local
    /usr
    /sw
    /opt/local
    /opt )

IF(PB_LIBRARY_STATIC)
  SET(PB_LIBRARY ${PB_LIBRARY_STATIC})
  MESSAGE(STATUS "  OK : found static library: ${PB_LIBRARY}")
ELSE(PB_LIBRARY_STATIC)
  FIND_LIBRARY(PB_LIBRARY
    NAMES
      protobuf
      libprotobuf
    PATH_SUFFIXES
      lib64
      lib
    PATHS
      ${PC_PB_LIBDIR}
      ${PC_PB_LIBRARY_DIRS}
      $ENV{PB_PREFIX}
      ${PC_PBLITE_LIBDIR}
      ${PC_PBLITE_LIBRARY_DIRS}
      $ENV{PBLITE_PREFIX}
      /usr/local
      /usr
      /sw
      /opt/local
      /opt )
ENDIF(PB_LIBRARY_STATIC)

FIND_PATH(PB_COMPILER_PATH protoc
  PATHS 
    $ENV{PB_PREFIX}/bin
    $ENV{PBLITE_PREFIX}/bin
    /usr/local/bin
    /usr/bin /sw/bin
    /opt/local/bin
    /opt/bin )

SET(PB_FOUND "NO")

IF(PC_PB_INCLUDEDIR AND NOT PB_INCLUDE)
  SET(PB_INCLUDE "${PC_PB_INCLUDEDIR}")
ENDIF(PC_PB_INCLUDEDIR AND NOT PB_INCLUDE)

IF(PC_PB_INCLUDE_DIRS AND NOT PB_INCLUDE)
  SET(PB_INCLUDE "${PC_PB_INCLUDE_DIRS}")
ENDIF(PC_PB_INCLUDE_DIRS AND NOT PB_INCLUDE)

IF(PB_INCLUDE)
  MESSAGE(STATUS "  OK : protocol buffer includes : ${PB_INCLUDE}")
ELSE(PB_INCLUDE)
  MESSAGE(STATUS "! KO : protocol buffer includes")
ENDIF(PB_INCLUDE)

IF(PB_LIBRARY)
  MESSAGE(STATUS "  OK : protocol buffer libs : ${PB_LIBRARY}")
ELSE(PB_LIBRARY)
  MESSAGE(STATUS "! KO : protocol buffer libs")
ENDIF(PB_LIBRARY)

IF(PB_COMPILER_PATH)
  SET(PB_COMPILER "${PB_COMPILER_PATH}/protoc")
  MESSAGE(STATUS "  OK : protocol buffer compiler : ${PB_COMPILER}")
ELSE(PB_COMPILER_PATH)
  MESSAGE(STATUS "! KO : protocol buffer compiler")
ENDIF(PB_COMPILER_PATH)

IF(PB_INCLUDE AND PB_LIBRARY AND PB_COMPILER)
   SET(PB_FOUND TRUE)
ELSE(PB_INCLUDE AND PB_LIBRARY AND PB_COMPILER)
   UNSET(PB_LIBRARY)
   UNSET(PB_INCLUDE)
   SET(PB_COMPILER "echo ERROR: ")
ENDIF(PB_INCLUDE AND PB_LIBRARY AND PB_COMPILER)

IF(PB_FOUND)
  MESSAGE(STATUS "  OK : Google protocol buffers found: Lib=${PB_LIBRARY} Compiler=${PB_COMPILER} Inc=${PB_INCLUDE}")
ELSE(PB_FOUND)
  MESSAGE(STATUS "! KO : Google protocol buffers NOT found")
  # setting this variable to a dummy value
  SET(PB_INCLUDE "/protocol-buffers/not/found/cmake/do-not/bark")
ENDIF(PB_FOUND)

