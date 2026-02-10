# frozen_string_literal: true

module ::DiscourseReachAndRights
  class RequestCacheMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      ::DiscourseReachAndRights::StatsStore.clear!
    end
  end
end
