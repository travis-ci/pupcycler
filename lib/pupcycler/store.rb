# frozen_string_literal: true

require 'time'

require 'pupcycler'

module Pupcycler
  class Store
    TIME_COERCE = ->(s) { Time.parse(s) }
    private_constant :TIME_COERCE

    NAMESPACES = {
      devices: 'device:'
    }.freeze
    private_constant :NAMESPACES

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
      save_for_device('heartbeats', device_id)
    end

    def fetch_heartbeat(device_id: '')
      fetch_for_device('heartbeats', device_id, default_value: nil,
                                                coerce: TIME_COERCE)
    end

    def save_reboot(device_id: '')
      save_for_device('reboots', device_id)
    end

    def fetch_reboot(device_id: '')
      fetch_for_device('reboots', device_id, default_value: nil,
                                             coerce: TIME_COERCE)
    end

    def save_startup(device_id: '')
      save_for_device('startups', device_id)
    end

    def fetch_startup(device_id: '')
      fetch_for_device('startups', device_id, default_value: nil,
                                              coerce: TIME_COERCE)
    end

    def save_shutdown(device_id: '')
      save_for_device('shutdowns', device_id)
    end

    def fetch_shutdown(device_id: '')
      fetch_for_device('shutdowns', device_id, default_value: nil,
                                               coerce: TIME_COERCE)
    end

    def save_state(device_id: '', state: '')
      save_for_device('states', device_id, value: state, count: false)
    end

    def fetch_state(device_id: '')
      fetch_for_device('states', device_id, default_value: 'up')
    end

    def save_boop(device_id: '')
      save_for_device('boops', device_id, value: now, count: false)
    end

    def save_hostname(device_id: '', hostname: '')
      save_for_device(
        'hostnames', device_id, value: hostname, count: false
      )
    end

    def fetch_devices
      devices_by_id = {}
      ns = NAMESPACES.fetch(:devices)

      DEVICE_KEYS_COERCIONS.each do |subkey, coerce|
        hgetall_coerce(
          "#{ns}#{subkey}s", coerce: coerce
        ).each do |device_id, value|
          devices_by_id[device_id] ||= EMPTY_DEVICE_RECORD.merge(id: device_id)
          devices_by_id[device_id][subkey] = value
        end

        hgetall_coerce(
          "#{ns}#{subkey}s:count", coerce: ->(s) { s.to_i }
        ).each do |device_id, count|
          devices_by_id[device_id] ||= EMPTY_DEVICE_RECORD.merge(id: device_id)
          devices_by_id[device_id]["#{subkey}_count".to_sym] = count
        end
      end

      devices_by_id.values.sort do |a, b|
        (a[:startup] || now).to_s <=> (b[:startup] || now).to_s
      end
    end

    def wipe_device(device_id: '')
      ns = NAMESPACES.fetch(:devices)

      redis_pool.with do |redis|
        redis.multi do |conn|
          DEVICE_KEYS_COERCIONS.keys.each do |subkey|
            conn.hdel("#{ns}#{subkey}s", device_id)
            conn.hdel("#{ns}#{subkey}s:count", device_id)
          end
        end
      end
    end

    def cleanup!(nil_check_keys: %i[heartbeat reboot shutdown startup state])
      fetch_devices.each do |dev|
        next unless nil_check_keys.map { |k| dev.fetch(k).nil? }.all?
        wipe_device(device_id: dev.fetch(:id))
        yield dev.fetch(:id) if block_given?
      end
    end

    private def fetch_for_device(key, device_id,
                                 default_value: nil, coerce: ->(v) { v })
      key = key.to_s.strip
      raise 'missing key' if key.empty?

      device_id = device_id.to_s.strip
      raise 'missing device id' if device_id.empty?

      ret = { value: default_value }
      ns = NAMESPACES.fetch(:devices)

      redis_pool.with do |redis|
        value = redis.hget("#{ns}#{key}", device_id).to_s.strip
        ret[:value] = coerce.call(value) unless value.empty?
      end

      ret.fetch(:value)
    end

    private def save_for_device(key, device_id, value: nil, count: true)
      key = key.to_s.strip
      raise 'missing key' if key.empty?

      device_id = device_id.to_s.strip
      raise 'missing device id' if device_id.empty?

      ns = NAMESPACES.fetch(:devices)

      redis_pool.with do |redis|
        redis.multi do |conn|
          conn.hset("#{ns}#{key}", device_id, value || now)
          next unless count
          conn.hincrby("#{ns}#{key}:count", device_id, 1)
        end
      end
    end

    private def hgetall_coerce(ns_key, coerce: nil)
      ret = {}
      coerce = ->(s) { s } if coerce.nil?

      redis_pool.with do |redis|
        ret.merge!(
          Hash[
            redis.hgetall(ns_key).map { |i, t| [i, coerce.call(t)] }
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
