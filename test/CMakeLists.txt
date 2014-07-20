MESSAGE(STATUS "cmake configure test/...")

LINK_LIBRARIES( ${Boost_LIBRARIES} ${PB_LIBRARY} )

ADD_EXECUTABLE( KeyValue_gtest KeyValue_gtest.cc )
TARGET_LINK_LIBRARIES( KeyValue_gtest interface_common gtest )
ADD_TEST( KeyValue_gtest ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/KeyValue_gtest )

# test if libs and includes are properly setup, so we can link applications w/ ZMQ
# ADD_EXECUTABLE( zmq_link_test zmq_link_test.cc )
# ADD_TEST( zmq_link_test ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/zmq_link_test )
# TARGET_LINK_LIBRARIES( zmq_link_test ${ZMQ_LIBRARY} )

# test if libs and includes are properly setup, so we can link applications w/ Postgres
# ADD_EXECUTABLE( pg_link_test pg_link_test.cc )
# ADD_TEST( pg_link_test ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/pg_link_test )
# TARGET_LINK_LIBRARIES( pg_link_test ${PG_LIBS} )


