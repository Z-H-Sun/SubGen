module OpenSSL
  class PKCS7
    class PKCS7 < PKCS7
      def initialize(*args)
        super(*args)

        warn("Warning: OpenSSL::PKCS7::PKCS7 is deprecated after Ruby 1.9; use OpenSSL::PKCS7 instead")
      end
    end

  end
end
