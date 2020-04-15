require 'net/protocol'
require 'uri'

module Net

  class HTTPBadResponse < StandardError; end
  class HTTPHeaderSyntaxError < StandardError; end

  class HTTP < Protocol

    Revision = %q$Revision: 29865 $.split[1]
    HTTPVersion = '1.1'
    @newimpl = true

    def HTTP.version_1_2
      @newimpl = true
    end

    def HTTP.version_1_1
      @newimpl = false
    end

    def HTTP.version_1_2?
      @newimpl
    end

    def HTTP.version_1_1?
      not @newimpl
    end

    class << HTTP
      alias is_version_1_1? version_1_1?
      alias is_version_1_2? version_1_2?
    end


    def HTTP.get_print(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port) {|res|
        res.read_body do |chunk|
          $stdout.print chunk
        end
      }
      nil
    end

    def HTTP.get(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port).body
    end

    def HTTP.get_response(uri_or_host, path = nil, port = nil, &block)
      if path
        host = uri_or_host
        new(host, port || HTTP.default_port).start {|http|
          return http.request_get(path, &block)
        }
      else
        uri = uri_or_host
        new(uri.host, uri.port).start {|http|
          return http.request_get(uri.request_uri, &block)
        }
      end
    end

    def HTTP.post_form(url, params)
      req = Post.new(url.path)
      req.form_data = params
      req.basic_auth url.user, url.password if url.user
      new(url.host, url.port).start {|http|
        http.request(req)
      }
    end


    def HTTP.default_port
      http_default_port()
    end

    def HTTP.http_default_port
      80
    end

    def HTTP.https_default_port
      443
    end

    def HTTP.socket_type
      BufferedIO
    end

    def HTTP.start(address, port = nil, p_addr = nil, p_port = nil, p_user = nil, p_pass = nil, &block)
      new(address, port, p_addr, p_port, p_user, p_pass).start(&block)
    end

    class << HTTP
      alias newobj new
    end

    def HTTP.new(address, port = nil, p_addr = nil, p_port = nil, p_user = nil, p_pass = nil)
      h = Proxy(p_addr, p_port, p_user, p_pass).newobj(address, port)
      h.instance_eval {
        @newimpl = ::Net::HTTP.version_1_2?
      }
      h
    end

    def initialize(address, port = nil)
      @address = address
      @port    = (port || HTTP.default_port)
      @curr_http_version = HTTPVersion
      @seems_1_0_server = false
      @close_on_empty_response = false
      @socket  = nil
      @started = false
      @open_timeout = nil
      @read_timeout = 60
      @debug_output = nil
      @use_ssl = false
      @ssl_context = nil
    end

    def inspect
      "#<#{self.class} #{@address}:#{@port} open=#{started?}>"
    end

    def set_debug_output(output)
      warn 'Net::HTTP#set_debug_output called after HTTP started' if started?
      @debug_output = output
    end

    attr_reader :address

    attr_reader :port

    attr_accessor :open_timeout

    attr_reader :read_timeout

    def read_timeout=(sec)
      @socket.read_timeout = sec if @socket
      @read_timeout = sec
    end

    def started?
      @started
    end

    alias active? started?

    attr_accessor :close_on_empty_response

    def use_ssl?
      false
    end

    def start
      raise IOError, 'HTTP session already opened' if @started
      if block_given?
        begin
          do_start
          return yield(self)
        ensure
          do_finish
        end
      end
      do_start
      self
    end

    def do_start
      connect
      @started = true
    end
    private :do_start

    def connect
      D "opening connection to #{conn_address()}..."
      s = timeout(@open_timeout) { TCPSocket.open(conn_address(), conn_port()) }
      D "opened"
      if use_ssl?
        unless @ssl_context.verify_mode
          warn "warning: peer certificate won't be verified in this SSL session"
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
        s.sync_close = true
      end
      @socket = BufferedIO.new(s)
      @socket.read_timeout = @read_timeout
      @socket.debug_output = @debug_output
      if use_ssl?
        if proxy?
          @socket.writeline sprintf('CONNECT %s:%s HTTP/%s',
                                    @address, @port, HTTPVersion)
          @socket.writeline "Host: #{@address}:#{@port}"
          if proxy_user
            credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
            credential.delete!("\r\n")
            @socket.writeline "Proxy-Authorization: Basic #{credential}"
          end
          @socket.writeline ''
          HTTPResponse.read_new(@socket).value
        end
        s.connect
        if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
          s.post_connection_check(@address)
        end
      end
      on_connect
    end
    private :connect

    def on_connect
    end
    private :on_connect

    def finish
      raise IOError, 'HTTP session not yet started' unless started?
      do_finish
    end

    def do_finish
      @started = false
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end
    private :do_finish


    public

    @is_proxy_class = false
    @proxy_addr = nil
    @proxy_port = nil
    @proxy_user = nil
    @proxy_pass = nil

    def HTTP.Proxy(p_addr, p_port = nil, p_user = nil, p_pass = nil)
      return self unless p_addr
      delta = ProxyDelta
      proxyclass = Class.new(self)
      proxyclass.module_eval {
        include delta
        @is_proxy_class = true
        @proxy_address = p_addr
        @proxy_port    = p_port || default_port()
        @proxy_user    = p_user
        @proxy_pass    = p_pass
      }
      proxyclass
    end

    class << HTTP
      def proxy_class?
        @is_proxy_class
      end

      attr_reader :proxy_address
      attr_reader :proxy_port
      attr_reader :proxy_user
      attr_reader :proxy_pass
    end

    def proxy?
      self.class.proxy_class?
    end

    def proxy_address
      self.class.proxy_address
    end

    def proxy_port
      self.class.proxy_port
    end

    def proxy_user
      self.class.proxy_user
    end

    def proxy_pass
      self.class.proxy_pass
    end

    alias proxyaddr proxy_address
    alias proxyport proxy_port

    private


    def conn_address
      address()
    end

    def conn_port
      port()
    end

    def edit_path(path)
      path
    end

    module ProxyDelta
      private

      def conn_address
        proxy_address()
      end

      def conn_port
        proxy_port()
      end

      def edit_path(path)
        use_ssl? ? path : "http://#{addr_port()}#{path}"
      end
    end


    public

    def get(path, initheader = nil, dest = nil, &block)
      res = nil
      request(Get.new(path, initheader)) {|r|
        r.read_body dest, &block
        res = r
      }
      unless @newimpl
        res.value
        return res, res.body
      end

      res
    end

    def head(path, initheader = nil) 
      res = request(Head.new(path, initheader))
      res.value unless @newimpl
      res
    end

    def post(path, data, initheader = nil, dest = nil, &block)
      res = nil
      request(Post.new(path, initheader), data) {|r|
        r.read_body dest, &block
        res = r
      }
      unless @newimpl
        res.value
        return res, res.body
      end
      res
    end

    def put(path, data, initheader = nil)   #:nodoc:
      res = request(Put.new(path, initheader), data)
      res.value unless @newimpl
      res
    end

    def proppatch(path, body, initheader = nil)
      request(Proppatch.new(path, initheader), body)
    end

    def lock(path, body, initheader = nil)
      request(Lock.new(path, initheader), body)
    end

    def unlock(path, body, initheader = nil)
      request(Unlock.new(path, initheader), body)
    end

    def options(path, initheader = nil)
      request(Options.new(path, initheader))
    end

    def propfind(path, body = nil, initheader = {'Depth' => '0'})
      request(Propfind.new(path, initheader), body)
    end

    def delete(path, initheader = {'Depth' => 'Infinity'})
      request(Delete.new(path, initheader))
    end

    def move(path, initheader = nil)
      request(Move.new(path, initheader))
    end

    def copy(path, initheader = nil)
      request(Copy.new(path, initheader))
    end

    def mkcol(path, body = nil, initheader = nil)
      request(Mkcol.new(path, initheader), body)
    end

    def trace(path, initheader = nil)
      request(Trace.new(path, initheader))
    end

    def request_get(path, initheader = nil, &block)
      request(Get.new(path, initheader), &block)
    end

    def request_head(path, initheader = nil, &block)
      request(Head.new(path, initheader), &block)
    end

    def request_post(path, data, initheader = nil, &block)
      request Post.new(path, initheader), data, &block
    end

    def request_put(path, data, initheader = nil, &block)
      request Put.new(path, initheader), data, &block
    end

    alias get2   request_get
    alias head2  request_head
    alias post2  request_post
    alias put2   request_put


    def send_request(name, path, data = nil, header = nil)
      r = HTTPGenericRequest.new(name,(data ? true : false),true,path,header)
      request r, data
    end

    def request(req, body = nil, &block)
      unless started?
        start {
          req['connection'] ||= 'close'
          return request(req, body, &block)
        }
      end
      if proxy_user()
        unless use_ssl?
          req.proxy_basic_auth proxy_user(), proxy_pass()
        end
      end

      req.set_body_internal body
      begin
        begin_transport req
        req.exec @socket, @curr_http_version, edit_path(req.path)
        begin
          res = HTTPResponse.read_new(@socket)
        end while res.kind_of?(HTTPContinue)
        res.reading_body(@socket, req.response_body_permitted?) {
          yield res if block_given?
        }
        end_transport req, res
      rescue => exception
        D "Conn close because of error #{exception}"
        @socket.close if @socket and not @socket.closed?
        raise exception
      end

      res
    end

    private

    def begin_transport(req)
      if @socket.closed?
        connect
      end
      if @seems_1_0_server
        req['connection'] ||= 'close'
      end
      if not req.response_body_permitted? and @close_on_empty_response
        req['connection'] ||= 'close'
      end
      req['host'] ||= addr_port()
    end

    def end_transport(req, res)
      @curr_http_version = res.http_version
      if not res.body and @close_on_empty_response
        D 'Conn close'
        @socket.close
      elsif keep_alive?(req, res)
        D 'Conn keep-alive'
        if @socket.closed?
          D 'Conn (but seems 1.0 server)'
          @seems_1_0_server = true
        end
      else
        D 'Conn close'
        @socket.close
      end
    end

    def keep_alive?(req, res)
      return false if /close/i =~ req['connection'].to_s
      return false if @seems_1_0_server
      return true  if /keep-alive/i =~ res['connection'].to_s
      return false if /close/i      =~ res['connection'].to_s
      return true  if /keep-alive/i =~ res['proxy-connection'].to_s
      return false if /close/i      =~ res['proxy-connection'].to_s
      (@curr_http_version == '1.1')
    end


    private

    def addr_port
      if use_ssl?
        address() + (port == HTTP.https_default_port ? '' : ":#{port()}")
      else
        address() + (port == HTTP.http_default_port ? '' : ":#{port()}")
      end
    end

    def D(msg)
      return unless @debug_output
      @debug_output << msg
      @debug_output << "\n"
    end

  end

  HTTPSession = HTTP


  module HTTPHeader

    def initialize_http_header(initheader)
      @header = {}
      return unless initheader
      initheader.each do |key, value|
        warn "net/http: warning: duplicated HTTP header: #{key}" if key?(key) and $VERBOSE
        @header[key.downcase] = [value.strip]
      end
    end

    def size
      @header.size
    end

    alias length size

    def [](key)
      a = @header[key.downcase] or return nil
      a.join(', ')
    end

    def []=(key, val)
      unless val
        @header.delete key.downcase
        return val
      end
      @header[key.downcase] = [val]
    end

    def add_field(key, val)
      if @header.key?(key.downcase)
        @header[key.downcase].push val
      else
        @header[key.downcase] = [val]
      end
    end

    def get_fields(key)
      return nil unless @header[key.downcase]
      @header[key.downcase].dup
    end

    def fetch(key, *args, &block)
      a = @header.fetch(key.downcase, *args, &block)
      a.join(', ')
    end

    def each_header
      @header.each do |k,va|
        yield k, va.join(', ')
      end
    end

    alias each each_header

    def each_name(&block)
      @header.each_key(&block)
    end

    alias each_key each_name

    def each_capitalized_name(&block)
      @header.each_key do |k|
        yield capitalize(k)
      end
    end

    def each_value
      @header.each_value do |va|
        yield va.join(', ')
      end
    end

    def delete(key)
      @header.delete(key.downcase)
    end

    def key?(key)
      @header.key?(key.downcase)
    end

    def to_hash
      @header.dup
    end

    def each_capitalized
      @header.each do |k,v|
        yield capitalize(k), v.join(', ')
      end
    end

    alias canonical_each each_capitalized

    def capitalize(name)
      name.split(/-/).map {|s| s.capitalize }.join('-')
    end
    private :capitalize

    def range
      return nil unless @header['range']
      self['Range'].split(/,/).map {|spec|
        m = /bytes\s*=\s*(\d+)?\s*-\s*(\d+)?/i.match(spec) or
                raise HTTPHeaderSyntaxError, "wrong Range: #{spec}"
        d1 = m[1].to_i
        d2 = m[2].to_i
        if    m[1] and m[2] then  d1..d2
        elsif m[1]          then  d1..-1
        elsif          m[2] then -d2..-1
        else
          raise HTTPHeaderSyntaxError, 'range is not specified'
        end
      }
    end

    def set_range(r, e = nil)
      unless r
        @header.delete 'range'
        return r
      end
      r = (r...r+e) if e
      case r
      when Numeric
        n = r.to_i
        rangestr = (n > 0 ? "0-#{n-1}" : "-#{-n}")
      when Range
        first = r.first
        last = r.last
        last -= 1 if r.exclude_end?
        if last == -1
          rangestr = (first > 0 ? "#{first}-" : "-#{-first}")
        else
          raise HTTPHeaderSyntaxError, 'range.first is negative' if first < 0
          raise HTTPHeaderSyntaxError, 'range.last is negative' if last < 0
          raise HTTPHeaderSyntaxError, 'must be .first < .last' if first > last
          rangestr = "#{first}-#{last}"
        end
      else
        raise TypeError, 'Range/Integer is required'
      end
      @header['range'] = ["bytes=#{rangestr}"]
      r
    end

    alias range= set_range

    def content_length
      return nil unless key?('Content-Length')
      len = self['Content-Length'].slice(/\d+/) or
          raise HTTPHeaderSyntaxError, 'wrong Content-Length format'
      len.to_i
    end
    
    def content_length=(len)
      unless len
        @header.delete 'content-length'
        return nil
      end
      @header['content-length'] = [len.to_i.to_s]
    end

    def chunked?
      return false unless @header['transfer-encoding']
      field = self['Transfer-Encoding']
      (/(?:\A|[^\-\w])chunked(?![\-\w])/i =~ field) ? true : false
    end

    def content_range
      return nil unless @header['content-range']
      m = %r<bytes\s+(\d+)-(\d+)/(\d+|\*)>i.match(self['Content-Range']) or
          raise HTTPHeaderSyntaxError, 'wrong Content-Range format'
      m[1].to_i .. m[2].to_i
    end

    def range_length
      r = content_range() or return nil
      r.end - r.begin + 1
    end

    def content_type
      return nil unless main_type()
      if sub_type()
      then "#{main_type()}/#{sub_type()}"
      else main_type()
      end
    end

    def main_type
      return nil unless @header['content-type']
      self['Content-Type'].split(';').first.to_s.split('/')[0].to_s.strip
    end
    
    def sub_type
      return nil unless @header['content-type']
      main, sub = *self['Content-Type'].split(';').first.to_s.split('/')
      return nil unless sub
      sub.strip
    end

    def type_params
      result = {}
      list = self['Content-Type'].to_s.split(';')
      list.shift
      list.each do |param|
        k, v = *param.split('=', 2)
        result[k.strip] = v.strip
      end
      result
    end

    def set_content_type(type, params = {})
      @header['content-type'] = [type + params.map{|k,v|"; #{k}=#{v}"}.join('')]
    end

    alias content_type= set_content_type

    def set_form_data(params, sep = '&')
      self.body = params.map {|k,v| "#{urlencode(k.to_s)}=#{urlencode(v.to_s)}" }.join(sep)
      self.content_type = 'application/x-www-form-urlencoded'
    end

    alias form_data= set_form_data

    def urlencode(str)
      str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end
    private :urlencode

    def basic_auth(account, password)
      @header['authorization'] = [basic_encode(account, password)]
    end

    def proxy_basic_auth(account, password)
      @header['proxy-authorization'] = [basic_encode(account, password)]
    end

    def basic_encode(account, password)
      'Basic ' + ["#{account}:#{password}"].pack('m').delete("\r\n")
    end
    private :basic_encode

  end


  class HTTPGenericRequest

    include HTTPHeader

    BUFSIZE = 16*1024

    def initialize(m, reqbody, resbody, path, initheader = nil)
      @method = m
      @request_has_body = reqbody
      @response_has_body = resbody
      raise ArgumentError, "HTTP request path is empty" if path.empty?
      @path = path
      initialize_http_header initheader
      self['Accept'] ||= '*/*'
      @body = nil
      @body_stream = nil
    end

    attr_reader :method
    attr_reader :path

    def inspect
      "\#<#{self.class} #{@method}>"
    end

    def request_body_permitted?
      @request_has_body
    end

    def response_body_permitted?
      @response_has_body
    end

    def body_exist?
      warn "Net::HTTPRequest#body_exist? is obsolete; use response_body_permitted?" if $VERBOSE
      response_body_permitted?
    end

    attr_reader :body

    def body=(str)
      @body = str
      @body_stream = nil
      str
    end

    attr_reader :body_stream

    def body_stream=(input)
      @body = nil
      @body_stream = input
      input
    end

    def set_body_internal(str)
      raise ArgumentError, "both of body argument and HTTPRequest#body set" if str and (@body or @body_stream)
      self.body = str if str
    end


    def exec(sock, ver, path)
      if @body
        send_request_with_body sock, ver, path, @body
      elsif @body_stream
        send_request_with_body_stream sock, ver, path, @body_stream
      else
        write_header sock, ver, path
      end
    end

    private

    def send_request_with_body(sock, ver, path, body)
      self.content_length = body.length
      delete 'Transfer-Encoding'
      supply_default_content_type
      write_header sock, ver, path
      sock.write body
    end

    def send_request_with_body_stream(sock, ver, path, f)
      unless content_length() or chunked?
        raise ArgumentError,
            "Content-Length not given and Transfer-Encoding is not `chunked'"
      end
      supply_default_content_type
      write_header sock, ver, path
      if chunked?
        while s = f.read(BUFSIZE)
          sock.write(sprintf("%x\r\n", s.length) << s << "\r\n")
        end
        sock.write "0\r\n\r\n"
      else
        while s = f.read(BUFSIZE)
          sock.write s
        end
      end
    end

    def supply_default_content_type
      return if content_type()
      warn 'net/http: warning: Content-Type did not set; using application/x-www-form-urlencoded' if $VERBOSE
      set_content_type 'application/x-www-form-urlencoded'
    end

    def write_header(sock, ver, path)
      buf = "#{@method} #{path} HTTP/#{ver}\r\n"
      each_capitalized do |k,v|
        buf << "#{k}: #{v}\r\n"
      end
      buf << "\r\n"
      sock.write buf
    end
  
  end


  class HTTPRequest < HTTPGenericRequest

    def initialize(path, initheader = nil)
      super self.class::METHOD,
            self.class::REQUEST_HAS_BODY,
            self.class::RESPONSE_HAS_BODY,
            path, initheader
    end
  end


  class HTTP   # reopen

    class Get < HTTPRequest
      METHOD = 'GET'
      REQUEST_HAS_BODY  = false
      RESPONSE_HAS_BODY = true
    end

    class Head < HTTPRequest
      METHOD = 'HEAD'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Post < HTTPRequest
      METHOD = 'POST'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Put < HTTPRequest
      METHOD = 'PUT'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Delete < HTTPRequest
      METHOD = 'DELETE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Options < HTTPRequest
      METHOD = 'OPTIONS'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    class Trace < HTTPRequest
      METHOD = 'TRACE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end


    class Propfind < HTTPRequest
      METHOD = 'PROPFIND'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Proppatch < HTTPRequest
      METHOD = 'PROPPATCH'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Mkcol < HTTPRequest
      METHOD = 'MKCOL'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Copy < HTTPRequest
      METHOD = 'COPY'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Move < HTTPRequest
      METHOD = 'MOVE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    class Lock < HTTPRequest
      METHOD = 'LOCK'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    class Unlock < HTTPRequest
      METHOD = 'UNLOCK'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end
  end

  module HTTPExceptions
    def initialize(msg, res)
      super msg
      @response = res
    end
    attr_reader :response
    alias data response
  end
  class HTTPError < ProtocolError
    include HTTPExceptions
  end
  class HTTPRetriableError < ProtoRetriableError
    include HTTPExceptions
  end
  class HTTPServerException < ProtoServerError
    include HTTPExceptions
  end
  class HTTPFatalError < ProtoFatalError
    include HTTPExceptions
  end


  class HTTPResponse
    def HTTPResponse.body_permitted?
      self::HAS_BODY
    end

    def HTTPResponse.exception_type
      self::EXCEPTION_TYPE
    end
  end

  class HTTPUnknownResponse < HTTPResponse
    HAS_BODY = true
    EXCEPTION_TYPE = HTTPError
  end
  class HTTPInformation < HTTPResponse
    HAS_BODY = false
    EXCEPTION_TYPE = HTTPError
  end
  class HTTPSuccess < HTTPResponse
    HAS_BODY = true
    EXCEPTION_TYPE = HTTPError
  end
  class HTTPRedirection < HTTPResponse
    HAS_BODY = true
    EXCEPTION_TYPE = HTTPRetriableError
  end
  class HTTPClientError < HTTPResponse
    HAS_BODY = true
    EXCEPTION_TYPE = HTTPServerException
  end
  class HTTPServerError < HTTPResponse
    HAS_BODY = true
    EXCEPTION_TYPE = HTTPFatalError
  end

  class HTTPContinue < HTTPInformation
    HAS_BODY = false
  end
  class HTTPSwitchProtocol < HTTPInformation
    HAS_BODY = false
  end

  class HTTPOK < HTTPSuccess
    HAS_BODY = true
  end
  class HTTPCreated < HTTPSuccess
    HAS_BODY = true
  end
  class HTTPAccepted < HTTPSuccess
    HAS_BODY = true
  end
  class HTTPNonAuthoritativeInformation < HTTPSuccess
    HAS_BODY = true
  end
  class HTTPNoContent < HTTPSuccess
    HAS_BODY = false
  end
  class HTTPResetContent < HTTPSuccess
    HAS_BODY = false
  end
  class HTTPPartialContent < HTTPSuccess
    HAS_BODY = true
  end

  class HTTPMultipleChoice < HTTPRedirection
    HAS_BODY = true
  end
  class HTTPMovedPermanently < HTTPRedirection
    HAS_BODY = true
  end
  class HTTPFound < HTTPRedirection
    HAS_BODY = true
  end
  HTTPMovedTemporarily = HTTPFound
  class HTTPSeeOther < HTTPRedirection
    HAS_BODY = true
  end
  class HTTPNotModified < HTTPRedirection
    HAS_BODY = false
  end
  class HTTPUseProxy < HTTPRedirection
    HAS_BODY = false
  end
  class HTTPTemporaryRedirect < HTTPRedirection
    HAS_BODY = true
  end

  class HTTPBadRequest < HTTPClientError
    HAS_BODY = true
  end
  class HTTPUnauthorized < HTTPClientError
    HAS_BODY = true
  end
  class HTTPPaymentRequired < HTTPClientError
    HAS_BODY = true
  end
  class HTTPForbidden < HTTPClientError
    HAS_BODY = true
  end
  class HTTPNotFound < HTTPClientError
    HAS_BODY = true
  end
  class HTTPMethodNotAllowed < HTTPClientError
    HAS_BODY = true
  end
  class HTTPNotAcceptable < HTTPClientError
    HAS_BODY = true
  end
  class HTTPProxyAuthenticationRequired < HTTPClientError
    HAS_BODY = true
  end
  class HTTPRequestTimeOut < HTTPClientError
    HAS_BODY = true
  end
  class HTTPConflict < HTTPClientError
    HAS_BODY = true
  end
  class HTTPGone < HTTPClientError
    HAS_BODY = true
  end
  class HTTPLengthRequired < HTTPClientError
    HAS_BODY = true
  end
  class HTTPPreconditionFailed < HTTPClientError
    HAS_BODY = true
  end
  class HTTPRequestEntityTooLarge < HTTPClientError
    HAS_BODY = true
  end
  class HTTPRequestURITooLong < HTTPClientError
    HAS_BODY = true
  end
  HTTPRequestURITooLarge = HTTPRequestURITooLong
  class HTTPUnsupportedMediaType < HTTPClientError
    HAS_BODY = true
  end
  class HTTPRequestedRangeNotSatisfiable < HTTPClientError
    HAS_BODY = true
  end
  class HTTPExpectationFailed < HTTPClientError
    HAS_BODY = true
  end

  class HTTPInternalServerError < HTTPServerError
    HAS_BODY = true
  end
  class HTTPNotImplemented < HTTPServerError
    HAS_BODY = true
  end
  class HTTPBadGateway < HTTPServerError
    HAS_BODY = true
  end
  class HTTPServiceUnavailable < HTTPServerError
    HAS_BODY = true
  end
  class HTTPGatewayTimeOut < HTTPServerError
    HAS_BODY = true
  end
  class HTTPVersionNotSupported < HTTPServerError
    HAS_BODY = true
  end



  class HTTPResponse

    CODE_CLASS_TO_OBJ = {
      '1' => HTTPInformation,
      '2' => HTTPSuccess,
      '3' => HTTPRedirection,
      '4' => HTTPClientError,
      '5' => HTTPServerError
    }
    CODE_TO_OBJ = {
      '100' => HTTPContinue,
      '101' => HTTPSwitchProtocol,

      '200' => HTTPOK,
      '201' => HTTPCreated,
      '202' => HTTPAccepted,
      '203' => HTTPNonAuthoritativeInformation,
      '204' => HTTPNoContent,
      '205' => HTTPResetContent,
      '206' => HTTPPartialContent,

      '300' => HTTPMultipleChoice,
      '301' => HTTPMovedPermanently,
      '302' => HTTPFound,
      '303' => HTTPSeeOther,
      '304' => HTTPNotModified,
      '305' => HTTPUseProxy,
      '307' => HTTPTemporaryRedirect,

      '400' => HTTPBadRequest,
      '401' => HTTPUnauthorized,
      '402' => HTTPPaymentRequired,
      '403' => HTTPForbidden,
      '404' => HTTPNotFound,
      '405' => HTTPMethodNotAllowed,
      '406' => HTTPNotAcceptable,
      '407' => HTTPProxyAuthenticationRequired,
      '408' => HTTPRequestTimeOut,
      '409' => HTTPConflict,
      '410' => HTTPGone,
      '411' => HTTPLengthRequired,
      '412' => HTTPPreconditionFailed,
      '413' => HTTPRequestEntityTooLarge,
      '414' => HTTPRequestURITooLong,
      '415' => HTTPUnsupportedMediaType,
      '416' => HTTPRequestedRangeNotSatisfiable,
      '417' => HTTPExpectationFailed,

      '500' => HTTPInternalServerError,
      '501' => HTTPNotImplemented,
      '502' => HTTPBadGateway,
      '503' => HTTPServiceUnavailable,
      '504' => HTTPGatewayTimeOut,
      '505' => HTTPVersionNotSupported
    }

    class << HTTPResponse
      def read_new(sock)   #:nodoc: internal use only
        httpv, code, msg = read_status_line(sock)
        res = response_class(code).new(httpv, code, msg)
        each_response_header(sock) do |k,v|
          res.add_field k, v
        end
        res
      end

      private

      def read_status_line(sock)
        str = sock.readline
        m = /\AHTTP(?:\/(\d+\.\d+))?\s+(\d\d\d)\s*(.*)\z/in.match(str) or
          raise HTTPBadResponse, "wrong status line: #{str.dump}"
        m.captures
      end

      def response_class(code)
        CODE_TO_OBJ[code] or
        CODE_CLASS_TO_OBJ[code[0,1]] or
        HTTPUnknownResponse
      end

      def each_response_header(sock)
        while true
          line = sock.readuntil("\n", true).sub(/\s+\z/, '')
          break if line.empty?
          m = /\A([^:]+):\s*/.match(line) or
              raise HTTPBadResponse, 'wrong header line format'
          yield m[1], m.post_match
        end
      end
    end

    public 

    include HTTPHeader

    def initialize(httpv, code, msg)
      @http_version = httpv
      @code         = code
      @message      = msg
      initialize_http_header nil
      @body = nil
      @read = false
    end

    attr_reader :http_version

    attr_reader :code

    attr_reader :message
    alias msg message

    def inspect
      "#<#{self.class} #{@code} #{@message} readbody=#{@read}>"
    end

    def to_ary
      warn "net/http.rb: warning: Net::HTTP v1.1 style assignment found at #{caller(1)[0]}; use `response = http.get(...)' instead." if $VERBOSE
      res = self.dup
      class << res
        undef to_ary
      end
      [res, res.body]
    end


    def code_type
      self.class
    end

    def error!
      raise error_type().new(@code + ' ' + @message.dump, self)
    end

    def error_type
      self.class::EXCEPTION_TYPE
    end

    def value
      error! unless self.kind_of?(HTTPSuccess)
    end


    def response
      warn "#{caller(1)[0]}: warning: HTTPResponse#response is obsolete" if $VERBOSE
      self
    end

    def header
      warn "#{caller(1)[0]}: warning: HTTPResponse#header is obsolete" if $VERBOSE
      self
    end

    def read_header
      warn "#{caller(1)[0]}: warning: HTTPResponse#read_header is obsolete" if $VERBOSE
      self
    end


    def reading_body(sock, reqmethodallowbody)
      @socket = sock
      @body_exist = reqmethodallowbody && self.class.body_permitted?
      begin
        yield
        self.body
      ensure
        @socket = nil
      end
    end

    def read_body(dest = nil, &block)
      if @read
        raise IOError, "#{self.class}\#read_body called twice" if dest or block
        return @body
      end
      to = procdest(dest, block)
      stream_check
      if @body_exist
        read_body_0 to
        @body = to
      else
        @body = nil
      end
      @read = true

      @body
    end

    def body
      read_body()
    end

    alias entity body

    private

    def read_body_0(dest)
      if chunked?
        read_chunked dest
        return
      end
      clen = content_length()
      if clen
        @socket.read clen, dest, true
        return
      end
      clen = range_length()
      if clen
        @socket.read clen, dest
        return
      end
      @socket.read_all dest
    end

    def read_chunked(dest)
      len = nil
      total = 0
      while true
        line = @socket.readline
        hexlen = line.slice(/[0-9a-fA-F]+/) or
            raise HTTPBadResponse, "wrong chunk size line: #{line}"
        len = hexlen.hex
        break if len == 0
        @socket.read len, dest; total += len
        @socket.read 2
      end
      until @socket.readline.empty?
      end
    end

    def stream_check
      raise IOError, 'attempt to read body out of block' if @socket.closed?
    end

    def procdest(dest, block)
      raise ArgumentError, 'both arg and block given for HTTP method' \
          if dest and block
      if block
        ReadAdapter.new(block)
      else
        dest || ''
      end
    end

  end


  class HTTP
    ProxyMod = ProxyDelta
  end
  module NetPrivate
    HTTPRequest = ::Net::HTTPRequest
  end

  HTTPInformationCode = HTTPInformation
  HTTPSuccessCode     = HTTPSuccess
  HTTPRedirectionCode = HTTPRedirection
  HTTPRetriableCode   = HTTPRedirection
  HTTPClientErrorCode = HTTPClientError
  HTTPFatalErrorCode  = HTTPClientError
  HTTPServerErrorCode = HTTPServerError
  HTTPResponceReceiver = HTTPResponse

end
