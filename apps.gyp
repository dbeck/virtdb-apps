{
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': { 'defines': ['DEBUG', '_DEBUG', ], },
      'Release': { 'defines': ['NDEBUG', 'RELEASE', ], },
    },
    'include_dirs': [
      'src/',
      'src/common/',
      'src/common/cppzmq/',
      'src/common/proto/',
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
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)', '-std=c++11', ],
        'xcode_settings': {
          'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
          'OTHER_LDFLAGS': [ '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)' ],
          'OTHER_CFLAGS': [ '-std=c++11', ],
        },
      },],
      ['OS=="linux"', {
        # 'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)', '-Werror' ],  -- TODO commented out only for temporary linux build fix
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)' ],
        'link_settings': {
          'ldflags': ['-Wl,--no-as-needed',],
          'libraries': [ '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)', ],
        },
      },],
    ],
  },
  'targets' : [
    {
      'target_name':       'diag_svc_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/diag_svc_sample.cc', ],
    },
    {
      'target_name':       'svc_config_svc_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/svc_config_svc_sample.cc', ],
    },
    {
      'target_name':       'diag_client_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/diag_client_sample.cc', ],
    },
  ],
}
