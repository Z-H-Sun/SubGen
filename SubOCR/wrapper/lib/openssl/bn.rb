
module OpenSSL
  class BN
    include Comparable
  end
end

class Integer
  def to_bn
    OpenSSL::BN::new(self)
  end
end
