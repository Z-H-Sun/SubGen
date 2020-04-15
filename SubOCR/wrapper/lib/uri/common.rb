
module URI
  module REGEXP
    module PATTERN


      ALPHA = "a-zA-Z"
      ALNUM = "#{ALPHA}\\d"

      HEX     = "a-fA-F\\d"
      ESCAPED = "%[#{HEX}]{2}"
      UNRESERVED = "-_.!~*'()#{ALNUM}"
      RESERVED = ";/?:@&=+$,\\[\\]"

      URIC = "(?:[#{UNRESERVED}#{RESERVED}]|#{ESCAPED})"
      URIC_NO_SLASH = "(?:[#{UNRESERVED};?:@&=+$,]|#{ESCAPED})"
      QUERY = "#{URIC}*"
      FRAGMENT = "#{URIC}*"

      DOMLABEL = "(?:[#{ALNUM}](?:[-#{ALNUM}]*[#{ALNUM}])?)"
      TOPLABEL = "(?:[#{ALPHA}](?:[-#{ALNUM}]*[#{ALNUM}])?)"
      HOSTNAME = "(?:#{DOMLABEL}\\.)*#{TOPLABEL}\\.?"

      IPV4ADDR = "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}"
      HEX4 = "[#{HEX}]{1,4}"
      LASTPART = "(?:#{HEX4}|#{IPV4ADDR})"
      HEXSEQ1 = "(?:#{HEX4}:)*#{HEX4}"
      HEXSEQ2 = "(?:#{HEX4}:)*#{LASTPART}"
      IPV6ADDR = "(?:#{HEXSEQ2}|(?:#{HEXSEQ1})?::(?:#{HEXSEQ2})?)"


      IPV6REF = "\\[#{IPV6ADDR}\\]"

      HOST = "(?:#{HOSTNAME}|#{IPV4ADDR}|#{IPV6REF})"
      PORT = '\d*'
      HOSTPORT = "#{HOST}(?::#{PORT})?"

      USERINFO = "(?:[#{UNRESERVED};:&=+$,]|#{ESCAPED})*"

      PCHAR = "(?:[#{UNRESERVED}:@&=+$,]|#{ESCAPED})"
      PARAM = "#{PCHAR}*"
      SEGMENT = "#{PCHAR}*(?:;#{PARAM})*"
      PATH_SEGMENTS = "#{SEGMENT}(?:/#{SEGMENT})*"

      SERVER = "(?:#{USERINFO}@)?#{HOSTPORT}"
      REG_NAME = "(?:[#{UNRESERVED}$,;:@&=+]|#{ESCAPED})+"
      AUTHORITY = "(?:#{SERVER}|#{REG_NAME})"

      REL_SEGMENT = "(?:[#{UNRESERVED};@&=+$,]|#{ESCAPED})+"

      SCHEME = "[#{ALPHA}][-+.#{ALPHA}\\d]*"

      ABS_PATH = "/#{PATH_SEGMENTS}"
      REL_PATH = "#{REL_SEGMENT}(?:#{ABS_PATH})?"
      NET_PATH   = "//#{AUTHORITY}(?:#{ABS_PATH})?"

      HIER_PART   = "(?:#{NET_PATH}|#{ABS_PATH})(?:\\?(?:#{QUERY}))?"
      OPAQUE_PART = "#{URIC_NO_SLASH}#{URIC}*"

      ABS_URI   = "#{SCHEME}:(?:#{HIER_PART}|#{OPAQUE_PART})"
      REL_URI = "(?:#{NET_PATH}|#{ABS_PATH}|#{REL_PATH})(?:\\?#{QUERY})?"

      URI_REF = "(?:#{ABS_URI}|#{REL_URI})?(?:##{FRAGMENT})?"

      X_ABS_URI = "
        (#{PATTERN::SCHEME}):                     (?# 1: scheme)
        (?:
           (#{PATTERN::OPAQUE_PART})              (?# 2: opaque)
        |
           (?:(?:
             //(?:
                 (?:(?:(#{PATTERN::USERINFO})@)?  (?# 3: userinfo)
                   (?:(#{PATTERN::HOST})(?::(\\d*))?))?(?# 4: host, 5: port)
               |
                 (#{PATTERN::REG_NAME})           (?# 6: registry)
               )
             |
             (?!//))                              (?# XXX: '//' is the mark for hostport)
             (#{PATTERN::ABS_PATH})?              (?# 7: path)
           )(?:\\?(#{PATTERN::QUERY}))?           (?# 8: query)
        )
        (?:\\#(#{PATTERN::FRAGMENT}))?            (?# 9: fragment)
      "
      X_REL_URI = "
        (?:
          (?:
            //
            (?:
              (?:(#{PATTERN::USERINFO})@)?       (?# 1: userinfo)
                (#{PATTERN::HOST})?(?::(\\d*))?  (?# 2: host, 3: port)
            |
              (#{PATTERN::REG_NAME})             (?# 4: registry)
            )
          )
        |
          (#{PATTERN::REL_SEGMENT})              (?# 5: rel_segment)
        )?
        (#{PATTERN::ABS_PATH})?                  (?# 6: abs_path)
        (?:\\?(#{PATTERN::QUERY}))?              (?# 7: query)
        (?:\\#(#{PATTERN::FRAGMENT}))?           (?# 8: fragment)
      "
    end # PATTERN


    ABS_URI = Regexp.new('^' + PATTERN::X_ABS_URI + '$', #'
                         Regexp::EXTENDED, 'N').freeze
    REL_URI = Regexp.new('^' + PATTERN::X_REL_URI + '$', #'
                         Regexp::EXTENDED, 'N').freeze

    URI_REF     = Regexp.new(PATTERN::URI_REF, false, 'N').freeze
    ABS_URI_REF = Regexp.new(PATTERN::X_ABS_URI, Regexp::EXTENDED, 'N').freeze
    REL_URI_REF = Regexp.new(PATTERN::X_REL_URI, Regexp::EXTENDED, 'N').freeze

    ESCAPED = Regexp.new(PATTERN::ESCAPED, false, 'N').freeze
    UNSAFE  = Regexp.new("[^#{PATTERN::UNRESERVED}#{PATTERN::RESERVED}]",
                         false, 'N').freeze

    SCHEME   = Regexp.new("^#{PATTERN::SCHEME}$", false, 'N').freeze #"
    USERINFO = Regexp.new("^#{PATTERN::USERINFO}$", false, 'N').freeze #"
    HOST     = Regexp.new("^#{PATTERN::HOST}$", false, 'N').freeze #"
    PORT     = Regexp.new("^#{PATTERN::PORT}$", false, 'N').freeze #"
    OPAQUE   = Regexp.new("^#{PATTERN::OPAQUE_PART}$", false, 'N').freeze #"
    REGISTRY = Regexp.new("^#{PATTERN::REG_NAME}$", false, 'N').freeze #"
    ABS_PATH = Regexp.new("^#{PATTERN::ABS_PATH}$", false, 'N').freeze #"
    REL_PATH = Regexp.new("^#{PATTERN::REL_PATH}$", false, 'N').freeze #"
    QUERY    = Regexp.new("^#{PATTERN::QUERY}$", false, 'N').freeze #"
    FRAGMENT = Regexp.new("^#{PATTERN::FRAGMENT}$", false, 'N').freeze #"
  end # REGEXP

  module Util # :nodoc:
    def make_components_hash(klass, array_hash)
      tmp = {}
      if array_hash.kind_of?(Array) &&
          array_hash.size == klass.component.size - 1
        klass.component[1..-1].each_index do |i|
          begin
            tmp[klass.component[i + 1]] = array_hash[i].clone
          rescue TypeError
            tmp[klass.component[i + 1]] = array_hash[i]
          end
        end

      elsif array_hash.kind_of?(Hash)
        array_hash.each do |key, value|
          begin
            tmp[key] = value.clone
          rescue TypeError
            tmp[key] = value
          end
        end
      else
        raise ArgumentError, 
          "expected Array of or Hash of components of #{klass.to_s} (#{klass.component[1..-1].join(', ')})"
      end
      tmp[:scheme] = klass.to_s.sub(/\A.*::/, '').downcase

      return tmp
    end
    module_function :make_components_hash
  end

  module Escape
    include REGEXP

    def escape(str, unsafe = UNSAFE)
      unless unsafe.kind_of?(Regexp)
        unsafe = Regexp.new("[#{Regexp.quote(unsafe)}]", false, 'N')
      end
      str.gsub(unsafe) do |us|
        tmp = ''
        us.each_byte do |uc|
          tmp << sprintf('%%%02X', uc)
        end
        tmp
      end
    end
    alias encode escape
    def unescape(str)
      str.gsub(ESCAPED) do
        $&[1,2].hex.chr
      end
    end
    alias decode unescape
  end

  include REGEXP
  extend Escape

  @@schemes = {}
  
  class Error < StandardError; end
  class InvalidURIError < Error; end
  class InvalidComponentError < Error; end
  class BadURIError < Error; end

  def self.split(uri)
    case uri
    when ''

    when ABS_URI
      scheme, opaque, userinfo, host, port, 
        registry, path, query, fragment = $~[1..-1]





      if !scheme
        raise InvalidURIError, 
          "bad URI(absolute but no scheme): #{uri}"
      end
      if !opaque && (!path && (!host && !registry))
        raise InvalidURIError,
          "bad URI(absolute but no path): #{uri}" 
      end

    when REL_URI
      scheme = nil
      opaque = nil

      userinfo, host, port, registry, 
        rel_segment, abs_path, query, fragment = $~[1..-1]
      if rel_segment && abs_path
        path = rel_segment + abs_path
      elsif rel_segment
        path = rel_segment
      elsif abs_path
        path = abs_path
      end





    else
      raise InvalidURIError, "bad URI(is not URI?): #{uri}"
    end

    path = '' if !path && !opaque
    ret = [
      scheme, 
      userinfo, host, port,
      registry, 
      path,
      opaque,
      query,
      fragment
    ]
    return ret
  end

  def self.parse(uri)
    scheme, userinfo, host, port, 
      registry, path, opaque, query, fragment = self.split(uri)

    if scheme && @@schemes.include?(scheme.upcase)
      @@schemes[scheme.upcase].new(scheme, userinfo, host, port, 
                                   registry, path, opaque, query, 
                                   fragment)
    else
      Generic.new(scheme, userinfo, host, port, 
                  registry, path, opaque, query, 
                  fragment)
    end
  end

  def self.join(*str)
    u = self.parse(str[0])
    str[1 .. -1].each do |x|
      u = u.merge(x)
    end
    u
  end

  def self.extract(str, schemes = nil, &block)
    if block_given?
      str.scan(regexp(schemes)) { yield $& }
      nil
    else
      result = []
      str.scan(regexp(schemes)) { result.push $& }
      result
    end
  end

  def self.regexp(schemes = nil)
    unless schemes
      ABS_URI_REF
    else
      /(?=#{Regexp.union(*schemes)}:)#{PATTERN::X_ABS_URI}/xn
    end
  end

end

module Kernel
  def URI(uri_str)
    URI.parse(uri_str)
  end
  module_function :URI
end
