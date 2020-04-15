require 'net/http'
require 'openssl'

module Net

  class HTTP
    remove_method :use_ssl?
    def use_ssl?
      @use_ssl
    end

    alias use_ssl use_ssl?

    def use_ssl=(flag)
      flag = (flag ? true : false)
      raise IOError, "use_ssl value changed, but session already started" \
          if started? and @use_ssl != flag
      if flag and not @ssl_context
        @ssl_context = OpenSSL::SSL::SSLContext.new
      end
      @use_ssl = flag
    end

    def self.ssl_context_accessor(name)
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def #{name}
          return nil unless @ssl_context
          @ssl_context.#{name}
        end

        def #{name}=(val)
          @ssl_context ||= OpenSSL::SSL::SSLContext.new
          @ssl_context.#{name} = val
        end
      End
    end

    ssl_context_accessor :key
    ssl_context_accessor :cert
    ssl_context_accessor :ca_file
    ssl_context_accessor :ca_path
    ssl_context_accessor :verify_mode
    ssl_context_accessor :verify_callback
    ssl_context_accessor :verify_depth
    ssl_context_accessor :cert_store

    def ssl_timeout
      return nil unless @ssl_context
      @ssl_context.timeout
    end

    def ssl_timeout=(sec)
      raise ArgumentError, 'Net::HTTP#ssl_timeout= called but use_ssl=false' \
          unless use_ssl?
      @ssl_context ||= OpenSSL::SSL::SSLContext.new
      @ssl_context.timeout = sec
    end

    alias timeout= ssl_timeout=

    def peer_cert
      return nil if not use_ssl? or not @socket
      @socket.io.peer_cert
    end
  end

end
