module Timeout

  class Error < Interrupt
  end
  class ExitException < ::Exception # :nodoc:
  end

  THIS_FILE = /\A#{Regexp.quote(__FILE__)}:/o
  CALLER_OFFSET = ((c = caller[0]) && THIS_FILE =~ c) ? 1 : 0

  def timeout(sec, klass = nil)
    return yield if sec == nil or sec.zero?
    raise ThreadError, "timeout within critical session" if Thread.critical
    exception = klass || Class.new(ExitException)
    begin
      x = Thread.current
      y = Thread.start {
        begin
          sleep sec
        rescue => e
          x.raise e
        else
          x.raise exception, "execution expired" if x.alive?
        end
      }
      yield sec
    rescue exception => e
      rej = /\A#{Regexp.quote(__FILE__)}:#{__LINE__-4}\z/o
      (bt = e.backtrace).reject! {|m| rej =~ m}
      level = -caller(CALLER_OFFSET).size
      while THIS_FILE =~ bt[level]
        bt.delete_at(level)
        level += 1
      end
      raise if klass
      raise Error, e.message, e.backtrace
    ensure
      if y and y.alive?
        y.kill
        y.join
      end
    end
  end

  module_function :timeout

end

def timeout(n, e = nil, &block)
  Timeout::timeout(n, e, &block)
end

TimeoutError = Timeout::Error

if __FILE__ == $0
  p timeout(5) {
    45
  }
  p timeout(5, TimeoutError) {
    45
  }
  p timeout(nil) {
    54
  }
  p timeout(0) {
    54
  }
  p timeout(5) {
    loop {
      p 10
      sleep 1
    }
  }
end

