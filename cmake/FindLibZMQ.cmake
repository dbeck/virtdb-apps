MESSAGE(STATUS "Detecting 0MQ")

pkg_check_modules(PC_ZMQ QUIET libzmq)

FIND_PATH(ZMQ_INCLUDE zmq.h 
  PATHS 
    ${PC_ZMQ_INCLUDEDIR}
    ${PC_ZMQ_INCLUDE_DIRS}
    $ENV{ZMQ_PREFIX}/include
    $ENV{ZMQ_INCLUDE}
	"$ENV{ProgramW6432}/ZeroM*/include"
	"$ENV{PROGRAMFILES}/ZeroM*/include"
    /usr/local/include
    /usr/include
    /sw/include
    /opt/local/include
    /opt/include )

FIND_LIBRARY(ZMQ_LIBRARY_STATIC
  NAMES
    zmq.a
    libzmq.a
  PATH_SUFFIXES
    lib64
    lib
  PATHS
    ${PC_ZMQ_LIBDIR}
    ${PC_ZMQ_LIBRARY_DIRS}
    $ENV{ZMQ_PREFIX}
    "$ENV{ProgramW6432}/ZeroM*/"
    "$ENV{PROGRAMFILES}/ZeroM*/"
    /usr/local
    /usr
    /sw
    /opt/local
    /opt )

IF(ZMQ_LIBRARY_STATIC)
  SET(ZMQ_LIBRARY ${ZMQ_LIBRARY_STATIC})
  MESSAGE(STATUS "  OK : Found static library : ${ZMQ_LIBRARY_STATIC}")
ELSE(ZMQ_LIBRARY_STATIC)
  MESSAGE(STATUS "  KO : Static library not found") 
  FIND_LIBRARY(ZMQ_LIBRARY
    NAMES
      zmq
      libzmq
      libzmq-v120-*.lib
      libzmq-v110-*.lib
      libzmq-v90-*.lib
    PATH_SUFFIXES
      lib64
      lib
    PATHS
      ${PC_ZMQ_LIBDIR}
      ${PC_ZMQ_LIBRARY_DIRS}
      $ENV{ZMQ_PREFIX}
      "$ENV{ProgramW6432}/ZeroM*/"
      "$ENV{PROGRAMFILES}/ZeroM*/"
      /usr/local
      /usr
      /sw
      /opt/local
      /opt )
ENDIF(ZMQ_LIBRARY_STATIC)

SET(ZMQ_FOUND "NO")

IF(PC_ZMQ_INCLUDEDIR AND NOT ZMQ_INCLUDE)
  SET(ZMQ_INCLUDE "${PC_ZMQ_INCLUDEDIR}")
ENDIF(PC_ZMQ_INCLUDEDIR AND NOT ZMQ_INCLUDE)

IF(PC_ZMQ_INCLUDE_DIRS AND NOT ZMQ_INCLUDE)
  SET(ZMQ_INCLUDE "${PC_ZMQ_INCLUDE_DIRS}")
ENDIF(PC_ZMQ_INCLUDE_DIRS AND NOT ZMQ_INCLUDE)

IF(ZMQ_INCLUDE)
  MESSAGE(STATUS "  OK : 0MQ includes : ${ZMQ_INCLUDE}")
ELSE(ZMQ_INCLUDE)
  MESSAGE(STATUS "  KO : 0MQ includes")
ENDIF(ZMQ_INCLUDE)

IF(ZMQ_LIBRARY)
  MESSAGE(STATUS "  OK : 0MQ libs : ${ZMQ_LIBRARY}")
ELSE(ZMQ_LIBRARY)
  MESSAGE(STATUS "  KO : 0MQ libs")
ENDIF(ZMQ_LIBRARY)

IF(ZMQ_INCLUDE AND ZMQ_LIBRARY)
   SET(ZMQ_FOUND TRUE)
ELSE(ZMQ_INCLUDE AND ZMQ_LIBRARY)
   UNSET(ZMQ_LIBRARY)
   UNSET(ZMQ_INCLUDE)
ENDIF(ZMQ_INCLUDE AND ZMQ_LIBRARY)

IF(ZMQ_FOUND)
  MESSAGE(STATUS "  0MQ found: Lib=${ZMQ_LIBRARY} Inc=${ZMQ_INCLUDE}")
ELSE(ZMQ_FOUND)
  MESSAGE(STATUS "  0MQ NOT found")
  # setting this variable to a dummy value
  SET(ZMQ_INCLUDE "/libzmq/not/found/cmake/do-not/bark")
ENDIF(ZMQ_FOUND)

