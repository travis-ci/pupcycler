# frozen_string_literal: true

require 'redis'
require 'redlock'

require 'pupcycler'

module Pupcycler
  class Worker
    def self.run
      new(
        loop_sleep: Pupcycler.config.worker_loop_sleep,
        once: Pupcycler.config.worker_run_once
      ).run
    end

    def initialize(redis_pool: nil, loop_sleep: 60, once: false)
      @redis_pool = redis_pool || Pupcycler.redis_pool
      @loop_sleep = loop_sleep
      @once = once
    end

    attr_reader :loop_sleep, :redis_pool
    private :loop_sleep
    private :redis_pool

    def run
      loop do
        Pupcycler.logger.info 'running tick'
        run_tick
        break if once
        Pupcycler.logger.info 'sleeping', seconds: loop_sleep
        sleep loop_sleep
      end
    end

    private def run_tick
      lock_manager.lock!('worker_tick', loop_sleep * 1_000) do
        upcycler.upcycle_stale_workers
      end
    rescue Redlock::LockError => e
      Pupcycler.logger.error e
    end

    private def upcycler
      @upcycler ||= Pupcycler::Upcycler.new
    end

    private def lock_manager
      @lock_manager ||= Redlock::Client.new(
        [
          Redis.new(url: Pupcycler.config.redis_url)
        ]
      )
    end
  end
end
