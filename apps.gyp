{
  'variables': {
    'proto_libdir' :      '<!(pkg-config --libs-only-L protobuf)',
    'zmq_libdir' :        '<!(pkg-config --libs-only-L libzmq)',
    'sodium_libdir':      '<!(./filedir_1.sh "libsodium.[ads]*" $HOME/libsodium-install)',
    'sodium_lib':         '<!(./if_exists.sh <(sodium_libdir) "-lsodium" -L/sodium/lib/not/found)',
    'app_ldflagsx':    [
                          '<!(./libdir_1.sh "libprotobuf.[ads]*" $HOME/protobuf-install /usr/local/lib)',
                          '<!(./libdir_1.sh "libzmq.[ads]*" $HOME/libzmq-install /usr/local/lib)',
                          '<!(./libdir_1.sh "libsodium.[ads]*" $HOME/libsodium-install /usr/local/lib)',
                          '<!@(./genrpath.sh "<(proto_libdir)" "<(zmq_libdir)") ',
                       ],
    'app_libsx':       [ 
                         '<!@(pkg-config --libs-only-L --libs-only-l protobuf libzmq)',
                         '<(sodium_lib)',
                       ],
  },
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
    'link_settings': {
      'ldflags':    [ '<@(app_ldflagsx)', ],
      'libraries':  [ '<@(app_libsx)', ],
    },
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
        'cflags': [ '<!@(pkg-config --cflags protobuf libzmq)' ],
        'link_settings': {
          'ldflags':    [ '-Wl,--no-as-needed', ],
          'libraries':  [ '-lrt', ],
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
      'target_name':       'simple-cache',
      'type':              'executable',
      'dependencies':      [
                             'src/common/common.gyp:cachedb',
                             'src/common/common.gyp:dsproxy',
                             'src/common/common.gyp:common',
                           ],
      'sources':           [
                             'src/simple-cache/main.cc',
                             'src/simple-cache/query_data.cc',
                             'src/simple-cache/query_data.hh',
                           ],
    },
    {
      'target_name':       'load-endpoint',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/load-endpoint/main.cc', ],
    },
    {
      'target_name':       'dump-table',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/dump-table/main.cc', ],
    },
    {
      'target_name':       'field-humanizer',
      'type':              'executable',
      'dependencies':      [ 'src/common/common.gyp:common', ],
      'sources':           [ 'src/field-humanizer/main.cc', ],
    },
  ],
}

