module OpenSSL
  class Digest

    alg = %w(DSS DSS1 MD2 MD4 MD5 MDC2 RIPEMD160 SHA SHA1)
    if OPENSSL_VERSION_NUMBER > 0x00908000
      alg += %w(SHA224 SHA256 SHA384 SHA512)
    end

    def self.digest(name, data)
        super(data, name)
    end

    alg.each{|name|
      klass = Class.new(Digest){
        define_method(:initialize){|*data|
          if data.length > 1
            raise ArgumentError,
              "wrong number of arguments (#{data.length} for 1)"
          end
          super(name, data.first)
        }
      }
      singleton = (class << klass; self; end)
      singleton.class_eval{
        define_method(:digest){|data| Digest.digest(name, data) }
        define_method(:hexdigest){|data| Digest.hexdigest(name, data) }
      }
      const_set(name, klass)
    }

    class Digest < Digest
      def initialize(*args)
        # add warning
        super(*args)
      end
    end

  end
end

