MESSAGE(STATUS "cmake configure test/...")

LINK_LIBRARIES( interface_meta_data ${Boost_LIBRARIES} )

ADD_EXECUTABLE( zmq_link_test zmq_link_test.cc )
ADD_TEST( zmq_link_test ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/zmq_link_test )

