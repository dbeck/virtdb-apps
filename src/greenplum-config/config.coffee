log = require 'loglevel'
log.setLevel 'debug'

class Config
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
