
module URI
  VERSION_CODE = '000911'.freeze
  VERSION = VERSION_CODE.scan(/../).collect{|n| n.to_i}.join('.').freeze

end

require 'uri/common'
require 'uri/generic'
require 'uri/ftp'
require 'uri/http'
require 'uri/https'
require 'uri/ldap'
require 'uri/ldaps'
require 'uri/mailto'
