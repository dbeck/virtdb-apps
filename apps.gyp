{
  'target_defaults': {
    'default_configuration': 'Debug',
    'configurations': {
      'Debug': {
        'defines':  ['DEBUG', '_DEBUG', ],
        'cflags':   ['-O0', '-g3', ],
        'ldflags':  ['-g3', ],
        'xcode_settings': {
          'OTHER_CFLAGS':  [ '-O0', '-g3', ],
          'OTHER_LDFLAGS': [ '-g3', ],
        },
      },
      'Release': {
        'defines': ['NDEBUG', 'RELEASE', ],
        'cflags': ['-O3', ],
        'xcode_settings': {
          'OTHER_LDFLAGS': [ '-O3', ],
        },
      },
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
      '-Wall',
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
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq) -g3' ],
        'variables': {
          'proto_libdir' : '<!(pkg-config --libs-only-L protobuf)',
          'zmq_libdir' :   '<!(pkg-config --libs-only-L libzmq)',
        },
        'link_settings': {
          'ldflags': ['-Wl,--no-as-needed -g3',],
          'libraries': [ 
                         '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)',
                         '<!@(./genrpath.sh "<(proto_libdir)" "<(zmq_libdir)" )',
                       ],
        },
      },],
    ],
  },
  'targets' : [
    {
      'target_name':       'diag-service',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/diag-service/main.cc', ],
    },
    {
      'target_name':       'config-service',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/config-service/main.cc', ],
    },
    {
      'target_name':       'save-configs',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/save-configs/main.cc', ],
    },
    {
      'target_name':       'load-config',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/load-config/main.cc', ],
    },
    {
      'target_name':       'remove-endpoint',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/remove-endpoint/main.cc', ],
    },
    {
      'target_name':       'save-endpoints',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/save-endpoints/main.cc', ],
    },
    {
      'target_name':       'load-endpoint',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/load-endpoint/main.cc', ],
    },

    {
      'target_name':       'testdata-provider',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/testdata-provider/main.cc', ],
    },
    {
      'target_name':       'diag_client_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/diag_client_sample.cc', ],
    },
    {
      'target_name':       'config_client_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/config_client_sample.cc', ],
    },
    {
      'target_name':       'dataprovider_client_sample',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'sample/dataprovider_client_sample.cc', ],
    },
  ],
}

