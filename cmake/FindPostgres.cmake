MESSAGE(STATUS "Detecting Postgres Libs and Includes")

FIND_PATH(PG_CONFIG_PATH pg_config
  PATHS 
    $ENV{PG_PREFIX}/bin
    /usr/local/bin
    /usr/bin /sw/bin
    /opt/local/bin
    /opt/bin )

IF(PG_CONFIG_PATH)
  MESSAGE(STATUS "  OK : found pg_config at: ${PG_CONFIG_PATH}")
  SET(PG_CONFIG ${PG_CONFIG_PATH}/pg_config)
  MESSAGE(STATUS "  OK : PG_CONFIG      = ${PG_CONFIG}")
ELSE(PG_CONFIG_PATH)
  MESSAGE(STATUS "! KO : pg_config not found")
ENDIF(PG_CONFIG_PATH)

SET(PG_FOUND "NO")

IF(PG_CONFIG)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --version            OUTPUT_VARIABLE  PG_VERSION)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --bindir             OUTPUT_VARIABLE  PG_BIN )
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --sysconfdir         OUTPUT_VARIABLE  PG_SYSCONFIGDIR)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --pgxs               OUTPUT_VARIABLE  PG_PGXS)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --pkglibdir          OUTPUT_VARIABLE  PG_PKGLIBDIR)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --includedir-server  OUTPUT_VARIABLE  PG_INCLUDEDIR_SERVER )
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --includedir         OUTPUT_VARIABLE  PG_INCLUDEDIR )
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --libdir             OUTPUT_VARIABLE  PG_LIBDIR)
  EXEC_PROGRAM(${PG_CONFIG} /tmp ARGS --libs               OUTPUT_VARIABLE  PG_LIBS)

  IF(PG_CMAKE_VERBOSE)
    MESSAGE(STATUS "  OK : PG_BIN                = ${PG_BIN}")
    MESSAGE(STATUS "  OK : PG_SYSCONFIGDIR       = ${PG_SYSCONFIGDIR}")
    MESSAGE(STATUS "  OK : PG_PGXS               = ${PG_PGXS}")
    MESSAGE(STATUS "  OK : PG_PKGLIBDIR          = ${PG_PKGLIBDIR}")
    MESSAGE(STATUS "  OK : PG_INCLUDEDIR_SERVER  = ${PG_INCLUDEDIR_SERVER}")
  ENDIF(PG_CMAKE_VERBOSE)

  MESSAGE(STATUS "  OK : PG_VERSION     = ${PG_VERSION}")
  MESSAGE(STATUS "  OK : PG_INCLUDEDIR  = ${PG_INCLUDEDIR}")
  MESSAGE(STATUS "  OK : PG_LIBDIR      = ${PG_LIBDIR}")
  MESSAGE(STATUS "  OK : PG_LIBS        = ${PG_LIBS}")

  FIND_PATH(PG_INCLUDE_POSTGRES_H postgres.h PATHS ${PG_INCLUDEDIR_SERVER})
  FIND_PATH(PG_INCLUDE_PG_CONFIG_H pg_config.h PATHS ${PG_INCLUDEDIR})
  FIND_LIBRARY(PG_LIBPQ NAMES libpq.a libpq PATHS ${PG_LIBDIR})

ENDIF(PG_CONFIG)


IF(PG_INCLUDE_POSTGRES_H)
  IF(PG_CMAKE_VERBOSE)
    MESSAGE(STATUS "  OK : found postgres.h in ${PG_INCLUDE_POSTGRES_H}")
  ENDIF(PG_CMAKE_VERBOSE)
  IF(PG_INCLUDE_PG_CONFIG_H)
    MESSAGE(STATUS "  OK : found pg_config.h in ${PG_INCLUDE_PG_CONFIG_H}")
    IF(PG_LIBPQ)
      IF(PG_CMAKE_VERBOSE)
        MESSAGE(STATUS "  OK : libpq: ${PG_LIBPQ}")
      ENDIF(PG_CMAKE_VERBOSE)
    ELSE(PG_LIBPQ)
      MESSAGE(STATUS "! KO : libpq: NOT FOUND")
    ENDIF(PG_LIBPQ)
  ELSE(PG_INCLUDE_PG_CONFIG_H)
    MESSAGE(STATUS "! KO : pg_config.h: NOT FOUND")
  ENDIF(PG_INCLUDE_PG_CONFIG_H)
ELSE(PG_INCLUDE_POSTGRES_H)
  MESSAGE(STATUS "! KO : postgres.h: NOT FOUND")
ENDIF(PG_INCLUDE_POSTGRES_H)

IF(PG_LIBPQ AND PG_INCLUDEDIR AND PG_INCLUDE_PG_CONFIG_H)
  SET(PG_FOUND TRUE)
ENDIF(PG_LIBPQ AND PG_INCLUDEDIR AND PG_INCLUDE_PG_CONFIG_H)

IF(PG_FOUND)
  MESSAGE(STATUS "  OK : postgres found")
ELSE(PG_FOUND)
  MESSAGE(STATUS "! KO : postgres NOT found")
  SET(PG_INCLUDEDIR "/postgres-not-found/setting/this/so/cmake/doesnot/bark")
  SET(PG_INCLUDEDIR_SERVER "/postgres-not-found/setting/this/so/cmake/doesnot/bark")
ENDIF(PG_FOUND)

