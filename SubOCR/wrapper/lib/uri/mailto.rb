
require 'uri/generic'

module URI

  class MailTo < Generic
    include REGEXP

    DEFAULT_PORT = nil

    COMPONENT = [ :scheme, :to, :headers ].freeze


    HEADER_PATTERN = "(?:[^?=&]*=[^?=&]*)".freeze
    HEADER_REGEXP  = Regexp.new(HEADER_PATTERN, 'N').freeze
    MAILBOX_PATTERN = "(?:#{PATTERN::ESCAPED}|[^(),%?=&])".freeze
    MAILTO_REGEXP = Regexp.new(" # :nodoc:
      \\A
      (#{MAILBOX_PATTERN}*?)                          (?# 1: to)
      (?:
        \\?
        (#{HEADER_PATTERN}(?:\\&#{HEADER_PATTERN})*)  (?# 2: headers)
      )?
      (?:
        \\#
        (#{PATTERN::FRAGMENT})                        (?# 3: fragment)
      )?
      \\z
    ", Regexp::EXTENDED, 'N').freeze

    def self.build(args)
      tmp = Util::make_components_hash(self, args)

      if tmp[:to]
        tmp[:opaque] = tmp[:to]
      else
        tmp[:opaque] = ''
      end

      if tmp[:headers]
        tmp[:opaque] << '?'

        if tmp[:headers].kind_of?(Array)
          tmp[:opaque] << tmp[:headers].collect { |x|
            if x.kind_of?(Array)
              x[0] + '=' + x[1..-1].to_s
            else
              x.to_s
            end
          }.join('&')

        elsif tmp[:headers].kind_of?(Hash)
          tmp[:opaque] << tmp[:headers].collect { |h,v|
            h + '=' + v
          }.join('&')

        else
          tmp[:opaque] << tmp[:headers].to_s
        end
      end

      return super(tmp)
    end

    def initialize(*arg)
      super(*arg)

      @to = nil
      @headers = []

      if MAILTO_REGEXP =~ @opaque
         if arg[-1]
          self.to = $1
          self.headers = $2
        else
          set_to($1)
          set_headers($2)
        end

      else
        raise InvalidComponentError,
          "unrecognised opaque part for mailtoURL: #{@opaque}"
      end
    end

    attr_reader :to

    attr_reader :headers

    def check_to(v)
      return true unless v
      return true if v.size == 0

      if OPAQUE !~ v || /\A#{MAILBOX_PATTERN}*\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_to

    def set_to(v)
      @to = v
    end
    protected :set_to

    def to=(v)
      check_to(v)
      set_to(v)
      v
    end

    def check_headers(v)
      return true unless v
      return true if v.size == 0

      if OPAQUE !~ v || 
          /\A(#{HEADER_PATTERN}(?:\&#{HEADER_PATTERN})*)\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_headers

    def set_headers(v)
      @headers = []
      if v
        v.scan(HEADER_REGEXP) do |x|
          @headers << x.split(/=/o, 2)
        end
      end
    end
    protected :set_headers

    def headers=(v)
      check_headers(v)
      set_headers(v)
      v
    end

    def to_s
      @scheme + ':' + 
        if @to 
          @to
        else
          ''
        end + 
        if @headers.size > 0
          '?' + @headers.collect{|x| x.join('=')}.join('&')
        else
          ''
        end +
        if @fragment
          '#' + @fragment
        else
          ''
        end
    end
    
    def to_mailtext
      to = URI::unescape(@to)
      head = ''
      body = ''
      @headers.each do |x|
        case x[0]
        when 'body'
          body = URI::unescape(x[1])
        when 'to'
          to << ', ' + URI::unescape(x[1])
        else
          head << URI::unescape(x[0]).capitalize + ': ' +
            URI::unescape(x[1])  + "\n"
        end
      end

      return "To: #{to}
#{head}
#{body}
"
    end
    alias to_rfc822text to_mailtext
  end

  @@schemes['MAILTO'] = MailTo
end
