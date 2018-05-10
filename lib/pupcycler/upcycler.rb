# frozen_string_literal: true

require 'pupcycler'

module Pupcycler
  class Upcycler
    def initialize(cooldown_threshold: 900, staleness_threshold: 43_200,
                   unresponsiveness_threshold: 3_600)
      @cooldown_threshold = cooldown_threshold
      @staleness_threshold = staleness_threshold
      @unresponsiveness_threshold = unresponsiveness_threshold
    end

    attr_reader :cooldown_threshold, :staleness_threshold
    attr_reader :unresponsiveness_threshold
    private :cooldown_threshold
    private :staleness_threshold
    private :unresponsiveness_threshold

    def upcycle!
      worker_devices.each do |dev|
        if unresponsive?(store.fetch_heartbeat(device_id: dev.id))
          reboot(device_id: dev.id)
          next
        end

        if stale?(store.fetch_startup(device_id: dev.id))
          graceful_shutdown(device_id: dev.id)
        end
      end
    end

    def reboot(device_id: '')
      assert_device_cooled_down!(device_id: device_id)
      logger.warn 'rebooting', device_id: device_id
      packet_client.reboot(device_id: device_id)
      store.save_reboot(device_id: device_id)
    end

    def graceful_shutdown(device_id: '')
      logger.info 'gracefully shutting down', device_id: device_id
      store.save_state(device_id: device_id, state: 'down')
    end

    private def assert_device_cooled_down!(device_id: '')
      dev = packet_client.device(device_id: device_id)
      uptime = (now - dev.updated_at)
      return if uptime > cooldown_threshold
      raise 'device still cooling down ' \
            "uptime=#{uptime}s threshold=#{cooldown_threshold}"
    end

    private def unresponsive?(last_heartbeat)
      return false if last_heartbeat.nil?
      (now - last_heartbeat) > unresponsiveness_threshold
    end

    private def stale?(startup)
      return false if startup.nil?
      (now - startup) > staleness_threshold
    end

    private def worker_devices
      packet_client.devices.select do |dev|
        dev.tags.include?('worker')
      end
    end

    private def now
      Time.now.utc
    end

    private def store
      @store ||= Pupcycler.store
    end

    private def logger
      @logger ||= Pupcycler.logger
    end

    private def packet_client
      @packet_client ||= Pupcycler.packet_client
    end
  end
end
