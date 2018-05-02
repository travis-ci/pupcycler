# frozen_string_literal: true

require 'connection_pool'
require 'redis'
require 'redis-namespace'
require 'travis/logger'

module Pupcycler
  autoload :App, 'pupcycler/app'
  autoload :Config, 'pupcycler/config'
  autoload :PacketClient, 'pupcycler/packet_client'
  autoload :PacketDevice, 'pupcycler/packet_device'
  autoload :Store, 'pupcycler/store'
  autoload :Upcycler, 'pupcycler/upcycler'
  autoload :Worker, 'pupcycler/worker'

  def version
    ENV.fetch(
      'SOURCE_VERSION',
      `git rev-parse HEAD 2>/dev/null`
    ).strip
  end

  module_function :version

  def config
    @config ||= Pupcycler::Config.load
  end

  module_function :config

  def logger
    @logger ||= Travis::Logger.new(@logdev || $stdout, config)
  end

  module_function :logger

  attr_writer :logdev
  module_function :logdev=

  def redis_pool
    @redis_pool ||= ConnectionPool.new(config.redis_pool_options) do
      Redis::Namespace.new(
        :pupcycler, redis: Redis.new(url: config.redis_url)
      )
    end
  end

  module_function :redis_pool
end
