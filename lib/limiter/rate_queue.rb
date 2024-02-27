# frozen_string_literal: true

module Limiter
  class RateQueue
    EPOCH = 0.0

    def initialize(size, interval: 60, &blk)
      @size = size
      @interval = interval
      @thread_queue = []
      @times = Concurrent::Array.new(@size, EPOCH)
      @executions = 0

      @mutex = Mutex.new
      @blk = blk
    end

    def shift
      loop do
        @mutex.synchronize do
          if @executions < @size
            @executions += 1
            break
          end
          @thread_queue << Thread.current
        end
        sleep
      end

      time = @times.shift
      sleep_until(time + @interval)

      yield

      @times << clock.time

      @mutex.synchronize do
        @executions -= 1
        @thread_queue.shift&.wakeup
      end
    end

    private

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
