MESSAGE(STATUS "Detecting ICU")

pkg_check_modules(PC_ICU QUIET icu-i18n)

FIND_LIBRARY(ICU_I18N_LIB
  NAMES
    libicui18n.a icui18n.a icui18n
  PATH_SUFFIXES
    lib64
    lib
    ./
  PATHS
    ${PC_ICU_LIBRARY_DIRS}
    /usr/local/opt/icu4c
    /usr/local
    /usr/lib/x86_64-linux-gnu
    /usr
    /lib )

FIND_LIBRARY(ICU_UC_LIB
  NAMES
    libicuuc.a icuuc.a icuuc
  PATH_SUFFIXES
    lib64
    lib
    ./
  PATHS
    ${PC_ICU_LIBRARY_DIRS}
    /usr/local/opt/icu4c
    /usr/local
    /usr/lib/x86_64-linux-gnu
    /usr
    /lib )

FIND_LIBRARY(ICU_DATA_LIB
  NAMES
    libicudata.a icudata.a icudata
  PATH_SUFFIXES
    lib64
    lib
    ./
  PATHS
    ${PC_ICU_LIBRARY_DIRS}
    /usr/local/opt/icu4c
    /usr/local
    /usr/lib/x86_64-linux-gnu
    /usr
    /lib )

IF(ICU_I18N_LIB)
  MESSAGE(STATUS "  OK : icu-i18n lib: ${ICU_I18N_LIB}")
ELSE(ICU_I18N_LIB)
  MESSAGE(ERROR  "! KO : icu-i18n lib not found")
ENDIF(ICU_I18N_LIB)

IF(ICU_UC_LIB)
  MESSAGE(STATUS "  OK : icu-uc lib: ${ICU_UC_LIB}")
ELSE(ICU_UC_LIB)
  MESSAGE(ERROR  "! KO : icu-uc lib not found")
ENDIF(ICU_UC_LIB)

IF(ICU_DATA_LIB)
  MESSAGE(STATUS "  OK : icu-data lib: ${ICU_DATA_LIB}")
ELSE(ICU_DATA_LIB)
  MESSAGE(ERROR "! KO : icu-data lib not found")
ENDIF(ICU_DATA_LIB)

SET(ICU_LIBRARIES ${ICU_I18N_LIB} ${ICU_UC_LIB} ${ICU_DATA_LIB})
 
# INCLUDE(PrintVars)

