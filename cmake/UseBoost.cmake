# Boost libs
SET(Boost_USE_STATIC_LIBS ON) 
SET(Boost_USE_MULTITHREADED ON)  
SET(Boost_USE_STATIC_RUNTIME ON) 
SET(BOOST_ROOT "/usr/local")

FIND_PACKAGE(Boost 1.53.0 COMPONENTS system program_options thread)

IF(Boost_FOUND)
  # include_directories(${Boost_INCLUDE_DIRS}) 
  # add_executable(progname file1.cxx file2.cxx) 
  # target_link_libraries(progname ${Boost_LIBRARIES})
  MESSAGE(STATUS "Boost Includes: ${Boost_INCLUDE_DIRS}")
  MESSAGE(STATUS "Boost LIBS: ${Boost_LIBRARIES}")
ENDIF(Boost_FOUND)

