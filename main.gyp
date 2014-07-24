{
  'variables': {
    'protoc':               '<!(which protoc)',
    # note: this could be simplified later like: pkg-config --libs --static protobuf libzmq
    'protobuf_libs':        '<!(pkg-config --libs protobuf)',
    'protobuf_static':      '<!(pkg-config --static protobuf)',
    'protobuf_cflags':      '<!(pkg-config --cflags protobuf)',
    'protobuf_exec_prefix': '<!(pkg-config --variable=exec_prefix protobuf)',
    'protobuf_prefix':      '<!(pkg-config --variable=prefix protobuf)',
    'protobuf_libdir':      '<!(pkg-config --variable=libdir protobuf)',
    'protobuf_includedir':  '<!(pkg-config --variable=includedir protobuf)',
    'libzmq_libs':          '<!(pkg-config --libs libzmq)',
    'libzmq_static':        '<!(pkg-config --static libzmq)',
    'libzmq_cflags':        '<!(pkg-config --cflags libzmq)',
    'libzmq_exec_prefix':   '<!(pkg-config --variable=exec_prefix libzmq)',
    'libzmq_prefix':        '<!(pkg-config --variable=prefix libzmq)',
    'libzmq_libdir':        '<!(pkg-config --variable=libdir libzmq)',
    'libzmq_includedir':    '<!(pkg-config --variable=includedir libzmq)',
    'gcc_version':          '<!(gcc --version | head -1)',
    'bad_gcc':              '<!(gcc --version | grep -c 4.8.)',
  },
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': { 'defines': ['DEBUG', '_DEBUG', ], },
      'Release': { 'defines': ['NDEBUG', 'RELEASE', ], },
    },
    'include_dirs': [ 
      'src/',
      'install/include/node/',
      '/usr/local/include',
      '/usr/include',
    ],
    'cflags': [
      '-std=c++11',
    ],
    'defines': [ 
      'PIC',
      'STD_CXX_11',
      '_THREAD_SAFE',
    ],
    'target_conditions': [
      ['_type=="shared_library"', {'cflags': ['-fPIC']}],
      ['_type=="static_library"', {'cflags': ['-fPIC']}],
      ['_type=="executable"',     {'cflags': ['-fPIC']}],
    ],
    'conditions': [
      ['OS=="linux" and bad_gcc != 0', {
          'link_settings': { 'ldflags': ['-Wl,--no-as-needed',], },
        }, 
      ],
    ],
  },
  'targets' : [
    {
      'target_name': 'testme',
      'type': 'executable',
      'dependencies': [ 'common_pb_lib', 'meta_data_pb_lib', 'db_config_pb_lib', 'data_pb_lib' ],
      'sources': [ 'src/testme.cc', ],
      'link_settings': {
        'ldflags': [
          '-fPIC',
          '-L/usr/local/lib',
          '-L/usr/lib',
          '-L/opt/lib',
        ],
        'libraries': [ '-lprotobuf' ],
      },
    },
    {
      'target_name': 'dummy_metadata_service',
      'type': 'executable',
      'dependencies': [ 'common_pb_lib', 'meta_data_pb_lib', 'db_config_pb_lib', 'data_pb_lib' ],
      'sources': [ 'src/dummy_metadata_service.cc', ],
      'link_settings': {
        'ldflags': [
          '-fPIC',
          '-L/usr/local/lib',
          '-L/usr/lib',
          '-L/opt/lib',
        ],
        'libraries': [ '-lprotobuf' ],
      },
    },
    {
      'target_name': 'common_pb_lib',
      'type': 'static_library',
      'sources': [ 'src/common.pb.cc', ],
      'variables': { 'common_pb_lib_proto': 'src/proto/common.proto', },
      'actions': [ {
          'action_name': 'protoc_gen_common',
          'inputs': [ '<(common_pb_lib_proto)', ],
          'outputs': [ 'src/common.pb.cc', 'src/common.pb.h', ],
          'action': [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(common_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name': 'meta_data_pb_lib',
      'type': 'static_library',
      'dependencies': [ 'common_pb_lib' ],
      'sources': [ 'src/meta_data.pb.cc', ],
      'variables': {
        'meta_data_pb_lib_proto': 'src/proto/meta_data.proto',
        'common_pb_lib_h':        'src/common.pb.h',
       },
      'actions': [ {
          'action_name': 'protoc_gen_meta_data',
          'inputs': [ '<(meta_data_pb_lib_proto)', '<(common_pb_lib_h)', ],
          'outputs': [ 'src/meta_data.pb.cc', 'src/meta_data.pb.h', ],
          'action': [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(meta_data_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name': 'db_config_pb_lib',
      'type': 'static_library',
      'dependencies': [ 'meta_data_pb_lib','common_pb_lib', ],
      'sources': [ 'src/db_config.pb.cc', ],
      'variables': { 
         'db_config_pb_lib_proto': 'src/proto/db_config.proto',
         'meta_data_pb_lib_h':     'src/meta_data.pb.h',
         'common_pb_lib_h':        'src/common.pb.h',
       },
      'actions': [ {
          'action_name': 'protoc_gen_db_config',
          'inputs': [ '<(db_config_pb_lib_proto)', '<(meta_data_pb_lib_h)', '<(common_pb_lib_h)' ],
          'outputs': [ 'src/db_config.pb.cc', 'src/db_config.pb.h', ],
          'action': [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(db_config_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name': 'data_pb_lib',
      'type': 'static_library',
      'dependencies': [ 'meta_data_pb_lib','common_pb_lib', ],
      'sources': [ 'src/data.pb.cc', ],
      'variables': { 
         'data_pb_lib_proto':      'src/proto/data.proto',
         'meta_data_pb_lib_h':     'src/meta_data.pb.h',
         'common_pb_lib_h':        'src/common.pb.h',
       },
      'actions': [ {
          'action_name': 'protoc_gen_data',
          'inputs': [ '<(data_pb_lib_proto)', '<(meta_data_pb_lib_h)', '<(common_pb_lib_h)' ],
          'outputs': [ 'src/data.pb.cc', 'src/data.pb.h', ],
          'action': [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(data_pb_lib_proto)', ],
        }
      ],
    },
  ],
}
