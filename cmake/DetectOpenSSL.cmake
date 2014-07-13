# the work should already be done by the FindOpenSSL.cmake module
MESSAGE(STATUS "Detecting OpenSSL")

IF(OPENSSL_FOUND)
  MESSAGE(STATUS "  OK : OPENSSL_INCLUDE_DIR  = ${OPENSSL_INCLUDE_DIR}")
  MESSAGE(STATUS "  OK : OPENSSL_LIBRARIES    = ${OPENSSL_LIBRARIES}") 
  MESSAGE(STATUS "Found OpenSSL: ${OPENSSL_VERSION}")
ELSE(OPENSSL_FOUND)
  MESSAGE(STATUS "OpenSSL Not found!")
  # setting this variable to a dummy value
  SET(OPENSSL_INCLUDE_DIR "/openssl/not/found/cmake/do-not/bark")
ENDIF(OPENSSL_FOUND)

