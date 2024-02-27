# frozen_string_literal: true

module Limiter
  class RateQueue
    EPOCH = 0.0

    def initialize(size, interval: 60, &blk)
      @size = size
      @interval = interval
      @thread_queue = []
      @ring = Concurrent::Array.new(@size, EPOCH)
      @executions = 0

      @mutex = Mutex.new
      @blk = blk
    end

    def shift
      reserve_slot
      time = @ring.shift
      sleep_until(time + @interval)

      ret_val = yield

      @ring << clock.time

      @mutex.synchronize do
        @executions -= 1
        @thread_queue.shift&.wakeup
      end
      ret_val
    end

    private

    def reserve_slot
      loop do
        @mutex.synchronize do
          if @executions < @size
            @executions += 1
            return
          end
          @thread_queue << Thread.current
        end
        sleep
      end
    end

    def sleep_until(time)
      interval = time - clock.time
      return unless interval.positive?

      @blk&.call
      clock.sleep(interval)
    end

    def clock
      Clock
    end
  end
end
