# frozen_string_literal: true

module Limiter
  module Mixin
    def limit_method(method, rate:, interval: 60, &b)
      queue = RateQueue.new(rate, interval: interval, &b)

      mixin = Module.new do
        define_method(method) do |*args, **options, &blk|
          queue.shift do
            options.empty? ? super(*args, &blk) : super(*args, **options, &blk)
          end
        end
      end

      define_singleton_method("reset_#{method}_limit!") do
        queue.reset
      end

      prepend(mixin)
    end
  end
end
