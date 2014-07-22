{
  'includes': [
    '../../../include/node/common.gypi'
  ],
  "targets": [
    {
      "target_name": "dummy_svc",
      "sources": [ "dummy_svc.cc" ],
      "include_dirs": [
        "../../../include/node/"
      ],  
    }
  ]
}
