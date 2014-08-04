zmq  = require("zmq")
fs   = require("fs")
p    = require("node-protobuf")
pb   = new p(fs.readFileSync("../src/meta_data.pb.desc"))


