
require 'uri/generic'

module URI

  class HTTP < Generic
    DEFAULT_PORT = 80

    COMPONENT = [
      :scheme, 
      :userinfo, :host, :port, 
      :path, 
      :query, 
      :fragment
    ].freeze

    def self.build(args)
      tmp = Util::make_components_hash(self, args)
      return super(tmp)
    end

    def initialize(*arg)
      super(*arg)
    end

    def request_uri
      r = path_query
      if r[0] != ?/
        r = '/' + r
      end

      r
    end
  end

  @@schemes['HTTP'] = HTTP
end
