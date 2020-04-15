
require 'uri/http'

module URI

  class HTTPS < HTTP
    DEFAULT_PORT = 443
  end
  @@schemes['HTTPS'] = HTTPS
end
