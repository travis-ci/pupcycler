# frozen_string_literal: true

require 'redis'
require 'redlock'
require 'time'

require 'pupcycler'

module Pupcycler
  class Worker
    def self.run
      new(
        loop_sleep: Pupcycler.config.worker_loop_sleep,
        once: Pupcycler.config.worker_run_once,
        redis_url: Pupcycler.config.redis_url
      ).run
    end

    def initialize(loop_sleep: 60, once: false, redis_url: '')
      @loop_sleep = loop_sleep
      @once = once
      @redis_url = redis_url
    end

    attr_reader :loop_sleep, :once, :redis_url
    private :loop_sleep
    private :once
    private :redis_url

    def run
      loop do
        logger.info 'running tick'
        run_tick
        break if once
        logger.info 'sleeping', seconds: loop_sleep
        sleep loop_sleep
      end
    end

    private def run_tick
      lock_manager.lock!('worker_tick', loop_sleep * 1_000) do
        upcycler.upcycle!
      end
    rescue Redlock::LockError => e
      logger.error 'failed to lock', error: e
    rescue => e
      logger.error 'boomsies', error: e
    end

    private def upcycler
      @upcycler ||= Pupcycler.upcycler
    end

    private def lock_manager
      @lock_manager ||= Redlock::Client.new([Redis.new(url: redis_url)])
    end

    private def logger
      @logger ||= Pupcycler.logger
    end
  end
end
