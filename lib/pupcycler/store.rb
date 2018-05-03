# frozen_string_literal: true

require 'time'

require 'pupcycler'

module Pupcycler
  class Store
    TIME_COERCE = ->(s) { Time.parse(s) }
    private_constant :TIME_COERCE

    def initialize(redis_pool: nil)
      @redis_pool = redis_pool || Pupcycler.redis_pool
    end

    attr_reader :redis_pool
    private :redis_pool

    def save_heartbeat(device_id: '')
      save_for_device('device:heartbeats', device_id)
    end

    def fetch_heartbeat(device_id: '')
      fetch_for_device('device:heartbeats', device_id, default_value: nil,
                                                       coerce: TIME_COERCE)
    end

    def save_reboot(device_id: '')
      save_for_device('device:reboots', device_id)
    end

    def save_startup(device_id: '')
      save_for_device('device:startups', device_id)
    end

    def fetch_startup(device_id: '')
      fetch_for_device('device:states', device_id, default_value: nil,
                                                   coerce: TIME_COERCE)
    end

    def save_state(device_id: '', state: '')
      save_for_device('device:states', device_id, value: state)
    end

    def fetch_state(device_id: '')
      fetch_for_device('device:states', device_id, default_value: 'up')
    end

    def dump
      ret = {}

      {
        heartbeats: TIME_COERCE,
        reboots: TIME_COERCE,
        startups: TIME_COERCE,
        states: ->(s) { s }
      }.each do |subkey, coerce|
        ret[subkey.to_sym] = hgetall_coerce(
          "device:#{subkey}", coerce: coerce
        )
        ret[:"#{subkey}_count"] = hgetall_coerce(
          "device:#{subkey}:count", coerce: ->(s) { s.to_i }
        )
      end

      ret
    end

    private def fetch_for_device(key, device_id,
                                 default_value: nil, coerce: ->(v) { v })
      key = key.to_s.strip
      raise 'missing key' if key.empty?

      device_id = device_id.to_s.strip
      raise 'missing device id' if device_id.empty?

      ret = { value: default_value }

      redis_pool.with do |redis|
        value = redis.hget(key, device_id).to_s.strip
        ret[:value] = coerce.call(value) unless value.empty?
      end

      ret.fetch(:value)
    end

    private def save_for_device(key, device_id, value: nil)
      key = key.to_s.strip
      raise 'missing key' if key.empty?

      device_id = device_id.to_s.strip
      raise 'missing device id' if device_id.empty?

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.hset(key, device_id, value || now)
          conn.hincrby("#{key}:count", device_id, 1)
        end
      end
    end

    private def hgetall_coerce(key, coerce: ->(s) { s })
      ret = {}

      redis_pool.with do |redis|
        ret.merge!(
          redis.hgetall("device:#{key}").map { |i, t| [i, coerce.call(t)] }
        )
      end

      ret
    end

    private def now
      Time.now.utc.iso8601(3)
    end
  end
end
