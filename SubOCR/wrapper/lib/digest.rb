require 'digest.so'

module Digest
  def self.const_missing(name)
    case name
    when :SHA256, :SHA384, :SHA512
      lib = 'digest/sha2.so'
    else
      lib = File.join('digest', name.to_s.downcase)
    end

    begin
      require lib
    rescue LoadError => e
      raise LoadError, "library not found for class Digest::#{name} -- #{lib}", caller(1)
    end
    unless Digest.const_defined?(name)
      raise NameError, "uninitialized constant Digest::#{name}", caller(1)
    end
    Digest.const_get(name)
  end

  class ::Digest::Class
    def self.file(name)
      new.file(name)
    end
  end

  module Instance
    def file(name)
      File.open(name, "rb") {|f|
        buf = ""
        while f.read(16384, buf)
          update buf
        end
      }
      self
    end
  end
end

def Digest(name)
  Digest.const_get(name)
end
