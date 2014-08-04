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
  'targets' : [
    {
      'target_name':       'meta_data_svc_sample',
      'type':              'executable',
      'dependencies':      [ 'src/proto/proto.gyp:proto', ],
      'sources':           [ 'sample/meta_data_svc_sample.cc', ],
    },
  ],
}
