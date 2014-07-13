MESSAGE(STATUS "cmake configure test/...")

LINK_LIBRARIES( interface_meta_data ${Boost_LIBRARIES} )

# test if libs and includes are properly setup, so we can link applications w/ ZMQ
ADD_EXECUTABLE( zmq_link_test zmq_link_test.cc )
ADD_TEST( zmq_link_test ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/zmq_link_test )

# test if libs and includes are properly setup, so we can link applications w/ Postgres
ADD_EXECUTABLE( pg_link_test pg_link_test.cc )
ADD_TEST( pg_link_test ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/pg_link_test )

