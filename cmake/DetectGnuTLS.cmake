# the work should already be done by the FindGnuTLS.cmake module
MESSAGE(STATUS "Detecting GnuTLS")

IF(GNUTLS_FOUND)
  MESSAGE(STATUS "  OK : GNUTLS_INCLUDE_DIR : ${GNUTLS_INCLUDE_DIR}")
  MESSAGE(STATUS "  OK : GNUTLS_LIBRARIES   : ${GNUTLS_LIBRARIES}") 
  MESSAGE(STATUS "Found GnuTLS")
ELSE(GNUTLS_FOUND)
  MESSAGE(STATUS "GnuTLS Not found!")
  # setting this variable to a dummy value
  SET(GNUTLS_INCLUDE_DIR "/gnutls/not/found/cmake/do-not/bark")
ENDIF(GNUTLS_FOUND)

