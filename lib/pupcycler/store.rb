# frozen_string_literal: true

require 'time'

require 'pupcycler'

module Pupcycler
  class Store
    def initialize(redis_pool: nil)
      @redis_pool = redis_pool || Pupcycler.redis_pool
    end

    attr_reader :redis_pool
    private :redis_pool

    def save_heartbeat(device_id: '')
      mark_for_device('device:heartbeats', device_id)
    end

    def heartbeats
      hgetall_timestamps('device:heartbeats')
    end

    def save_upcycle(device_id: '')
      mark_for_device('device:upcycles', device_id)
    end

    def upcycles
      hgetall_timestamps('device:upcycles')
    end

    private def mark_for_device(key, device_id)
      key.strip!
      raise 'missing key' if key.empty?

      device_id.strip!
      raise 'missing device id' if device_id.empty?

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.hset(key, device_id, now)
          conn.hincrby("#{key}:count", device_id, 1)
        end
      end
    end

    private def hgetall_timestamps(key)
      ret = {}

      redis_pool.with do |redis|
        ret.merge!(
          redis.hgetall("device:#{key}").map { |i, t| [i, Time.parse(t)] }
        )
      end

      ret
    end

    private def now
      Time.now.utc.iso8601(3)
    end
  end
end
