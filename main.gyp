{
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': { 'defines': ['DEBUG', '_DEBUG', ], },
      'Release': { 'defines': ['NDEBUG', 'RELEASE', ], },
    },
    'include_dirs': [ 'src/', 'install/include/node/', ],
    'defines': [ 'PIC' ],
  },
  'targets' : [
    {
      'target_name': 'testme',
      'type': 'executable',
      'dependencies': [ 'common_pb_lib', 'meta_data_pb_lib', 'db_config_pb_lib' ],
      'sources': [ 'src/testme.cc', ],
    },
    {
      'target_name': 'common_pb_lib',
      'type': 'static_library',
      'sources': [ 'src/common.pb.cc', ],
      'variables': { 'common_pb_lib_proto': 'src/common.proto', },
      'actions': [ {
          'action_name': 'protoc_gen_common',
          'inputs': [ '<(common_pb_lib_proto)', ],
          'outputs': [ 'src/common.pb.cc', 'src/common.pb.h', ],
          'action': [ 'protoc', '--cpp_out=src/.', '-Isrc/.', '<(common_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name': 'meta_data_pb_lib',
      'type': 'static_library',
      'dependencies': [ 'common_pb_lib' ],
      'sources': [ 'src/meta_data.pb.cc', ],
      'variables': { 'meta_data_pb_lib_proto': 'src/meta_data.proto', },
      'actions': [ {
          'action_name': 'protoc_gen_meta_data',
          'inputs': [ '<(meta_data_pb_lib_proto)', ],
          'outputs': [ 'src/meta_data.pb.cc', 'src/meta_data.pb.h', ],
          'action': [ 'protoc', '--cpp_out=src/.', '-Isrc/.', '<(meta_data_pb_lib_proto)', ],
        }
      ],
    },
    {
      'target_name': 'db_config_pb_lib',
      'type': 'static_library',
      'dependencies': [ 'common_pb_lib','meta_data_pb_lib' ],
      'sources': [ 'src/db_config.pb.cc', ],
      'variables': { 'db_config_pb_lib_proto': 'src/db_config.proto', },
      'actions': [ {
          'action_name': 'protoc_gen_db_config',
          'inputs': [ '<(db_config_pb_lib_proto)', ],
          'outputs': [ 'src/db_config.pb.cc', 'src/db_config.pb.h', ],
          'action': [ 'protoc', '--cpp_out=src/.', '-Isrc/.', '<(db_config_pb_lib_proto)', ],
        }
      ],
    },
  ],
}