# frozen_string_literal: true

require 'hashr'
require 'travis/config'

module Pupcycler
  class Config < Travis::Config
    extend Hashr::Env
    self.env_namespace = 'PUPCYCLER'

    define(
      auth_tokens: ENV.fetch(
        'PUPCYCLER_AUTH_TOKENS',
        ENV.fetch(
          'AUTH_TOKENS', 'notset'
        )
      ).split(',').map(&:strip),
      log_level: 'info',
      logger: { format_type: 'l2met', thread_id: true },
      packet_auth_token: ENV.fetch(
        'PUPCYCLER_PACKET_AUTH_TOKEN',
        ENV.fetch(
          'PACKET_AUTH_TOKEN', 'notset'
        )
      ),
      packet_project_id: ENV.fetch(
        'PUPCYCLER_PACKET_PROJECT_ID',
        ENV.fetch(
          'PACKET_PROJECT_ID', 'notset'
        )
      ),
      redis_url: ENV.fetch(
        ENV.fetch('REDIS_PROVIDER', 'REDIS_URL'), 'redis://localhost:6379/0'
      ),
      redis_pool_options: { size: 5, timeout: 3 },
      upcycler_thresholds: { unresponsive: 3_600, stale: 43_200 },
      worker_loop_sleep: 60,
      worker_run_once: false
    )
  end
end
