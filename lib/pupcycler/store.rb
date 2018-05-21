# frozen_string_literal: true

require 'time'

require 'pupcycler'

module Pupcycler
  class Store
    TIME_COERCE = ->(s) { Time.parse(s) }
    private_constant :TIME_COERCE

    DEVICE_KEYS_COERCIONS = {
      boop: TIME_COERCE,
      heartbeat: TIME_COERCE,
      hostname: nil,
      reboot: TIME_COERCE,
      shutdown: TIME_COERCE,
      startup: TIME_COERCE,
      state: nil
    }.freeze
    private_constant :DEVICE_KEYS_COERCIONS

    EMPTY_DEVICE_RECORD = Hash[
      DEVICE_KEYS_COERCIONS.keys.map { |k| [k, nil] }
    ].freeze
    private_constant :EMPTY_DEVICE_RECORD

    def initialize(redis_pool: nil)
      @redis_pool = redis_pool
    end

    attr_accessor :redis_pool

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

    def fetch_reboot(device_id: '')
      fetch_for_device('device:reboots', device_id, default_value: nil,
                                                    coerce: TIME_COERCE)
    end

    def save_startup(device_id: '')
      save_for_device('device:startups', device_id)
    end

    def fetch_startup(device_id: '')
      fetch_for_device('device:startups', device_id, default_value: nil,
                                                     coerce: TIME_COERCE)
    end

    def save_shutdown(device_id: '')
      save_for_device('device:shutdowns', device_id)
    end

    def fetch_shutdown(device_id: '')
      fetch_for_device('device:shutdowns', device_id, default_value: nil,
                                                      coerce: TIME_COERCE)
    end

    def save_state(device_id: '', state: '')
      save_for_device('device:states', device_id, value: state, count: false)
    end

    def fetch_state(device_id: '')
      fetch_for_device('device:states', device_id, default_value: 'up')
    end

    def save_boop(device_id: '')
      save_for_device('device:boops', device_id, value: now, count: false)
    end

    def save_hostname(device_id: '', hostname: '')
      save_for_device(
        'device:hostnames', device_id, value: hostname, count: false
      )
    end

    def fetch_devices
      devices_by_id = {}

      DEVICE_KEYS_COERCIONS.each do |subkey, coerce|
        hgetall_coerce(
          "#{subkey}s", coerce: coerce
        ).each do |device_id, value|
          devices_by_id[device_id] ||= EMPTY_DEVICE_RECORD.merge(id: device_id)
          devices_by_id[device_id][subkey] = value
        end

        hgetall_coerce(
          "#{subkey}s:count", coerce: ->(s) { s.to_i }
        ).each do |device_id, count|
          devices_by_id[device_id] ||= EMPTY_DEVICE_RECORD.merge(id: device_id)
          devices_by_id[device_id]["#{subkey}_count".to_sym] = count
        end
      end

      devices_by_id.values.sort do |a, b|
        (a[:startup] || now).to_s <=> (b[:startup] || now).to_s
      end
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

    private def save_for_device(key, device_id, value: nil, count: true)
      key = key.to_s.strip
      raise 'missing key' if key.empty?

      device_id = device_id.to_s.strip
      raise 'missing device id' if device_id.empty?

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.hset(key, device_id, value || now)
          next unless count
          conn.hincrby("#{key}:count", device_id, 1)
        end
      end
    end

    private def hgetall_coerce(key, coerce: nil)
      ret = {}
      coerce = ->(s) { s } if coerce.nil?

      redis_pool.with do |redis|
        ret.merge!(
          Hash[
            redis.hgetall("device:#{key}").map { |i, t| [i, coerce.call(t)] }
          ]
        )
      end

      ret
    end

    private def now
      Time.now.utc.iso8601(3)
    end
  end
end
