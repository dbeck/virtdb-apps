{
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': { 'defines': ['DEBUG', '_DEBUG', ], },
      'Release': { 'defines': ['NDEBUG', 'RELEASE', ], },
    },
    'include_dirs': [ 
      'src/',
      'src/cppzmq/',
      'install/include/node/',
      '/usr/local/include/',
      '/usr/include/',
      '<!@(pkg-config --variable=includedir protobuf libzmq)',
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
      ['OS=="mac"', { 
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)', ], 
        'xcode_settings': { 
          'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
          'OTHER_LDFLAGS': [ '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)' ],
        },
      },],
      ['OS=="linux"', { 
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)', '-Werror' ], 
        'link_settings': {
          'ldflags': ['-Wl,--no-as-needed',],
          'libraries': [ '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)', ], 
        },
      },],
    ],
  },
  'variables': {
    'protoc':                   '<!(which protoc)',
    'common_pb_lib_proto':      'src/proto/common.proto',
    'meta_data_pb_lib_proto':   'src/proto/meta_data.proto',
    'db_config_pb_lib_proto':   'src/proto/db_config.proto',
    'data_pb_lib_proto':        'src/proto/data.proto',
    'common_pb_lib_desc':       'src/common.desc',
    'meta_data_pb_lib_desc':    'src/meta_data.desc',
    'db_config_pb_lib_desc':    'src/db_config.desc',
    'data_pb_lib_desc':         'src/data.desc',
    'common_pb_srcs':           [ 'src/common.pb.h', 'src/common.pb.h', ],
    'meta_data_pb_srcs':        [ 'src/meta_data.pb.h', 'src/meta_data.pb.h', ],
    'db_config_pb_srcs':        [ 'src/db_config_data.pb.h', 'src/db_config_data.pb.h', ],
    'data_pb_srcs':             [ 'src/data.pb.h', 'src/data.pb.h', ],
  },
  'targets' : [
    {
      'target_name':       'meta_data_svc_sample',
      'type':              'executable',
      'dependencies':      [ 'common_pb_lib', 'meta_data_pb_lib', 'db_config_pb_lib', 'data_pb_lib' ],
      'sources':           [ 'sample/meta_data_svc_sample.cc', ],
    },
    {
      'target_name':       'common_pb_lib',
      'type':              'static_library',
      'sources':           [ 'src/common.pb.cc', ],
      'actions': [ {
          'action_name':   'protoc_gen_cpp_common',
          'inputs':        [ '<(common_pb_lib_proto)', ],
          'outputs':       [ '<@(common_pb_srcs)', ], 
          'action':        [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(common_pb_lib_proto)', ],
        },
      ],
    },
    {
      'target_name':       'common_pb_desc',
      'type':              'none',
      'sources':           [ '<(common_pb_lib_proto)', ],
      'actions': [ {
          'action_name':   'protoc_gen_cpp_common',
          'inputs':        [ '<(common_pb_lib_proto)', ],
          'outputs':       [ '<(common_pb_lib_desc)', ],
          'action':        [ '<(protoc)', '--descriptor_set_out=<(common_pb_lib_desc)', '--include_imports', '-Isrc/proto/.', '<(common_pb_lib_proto)', ],
        },
      ],
    },
    {
      'target_name':       'meta_data_pb_lib',
      'type':              'static_library',
      'dependencies':      [ 'common_pb_lib' ],
      'sources':           [ 'src/meta_data.pb.cc', ],
      'actions': [ {
          'action_name':   'protoc_gen_cpp_meta_data',
          'inputs':        [ '<(meta_data_pb_lib_proto)', '<@(common_pb_srcs)', ],
          'outputs':       [ '<@(meta_data_pb_srcs)', ],
          'action':        [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(meta_data_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name':       'db_config_pb_lib',
      'type':              'static_library',
      'dependencies':      [ 'meta_data_pb_lib','common_pb_lib', ],
      'sources':           [ 'src/db_config.pb.cc', ],
      'actions': [ {
          'action_name':   'protoc_gen_cpp_db_config',
          'inputs':        [ '<(db_config_pb_lib_proto)', '<@(meta_data_pb_srcs)', '<@(common_pb_srcs)' ],
          'outputs':       [ '<@(db_config_pb_srcs)', ],
          'action':        [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(db_config_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name':       'data_pb_lib',
      'type':              'static_library',
      'dependencies':      [ 'meta_data_pb_lib','common_pb_lib', ],
      'sources':           [ 'src/data.pb.cc', ],
      'actions': [ {
          'action_name':   'protoc_gen_cpp_data',
          'inputs':        [ '<(data_pb_lib_proto)', '<@(meta_data_pb_srcs)', '<(common_pb_srcs)' ],
          'outputs':       [ '<@(data_pb_srcs)', ],
          'action':        [ '<(protoc)', '--cpp_out=src/.', '-Isrc/proto/.', '<(data_pb_lib_proto)', ],
        }
      ],
    },
  ],
}
