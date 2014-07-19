require 'time'

module Raven
  # Middleware for Rack applications. Any errors raised by the upstream
  # application will be delivered to Sentry and re-raised.
  #
  # Synopsis:
  #
  #   require 'rack'
  #   require 'raven'
  #
  #   Raven.configure do |config|
  #     config.server = 'http://my_dsn'
  #   end
  #
  #   app = Rack::Builder.app do
  #     use Raven::Rack
  #     run lambda { |env| raise "Rack down" }
  #   end
  #
  # Use a standard Raven.configure call to configure your server credentials.
  class Rack
    def self.capture_exception(exception, env, options = {})
      if env["requested_at"]
        options[:time_spent] = Time.now - env[:requested_at]
      end
      Raven.capture_exception(exception, options) do |evt|
        evt.interface :http do |int|
          int.from_rack(env)
        end
      end
    end

    def self.capture_message(message, env, options = {})
      if env["requested_at"]
        options[:time_spent] = Time.now - env[:requested_at]
      end
      Raven.capture_message(message, options) do |evt|
        evt.interface :http do |int|
          int.from_rack(env)
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      # clear context at the beginning of the request to ensure a clean slate
      Context.clear!

      # store the current environment in our local context for arbitrary
      # callers
      env["requested_at"] = Time.now
      Raven.rack_context(env)

      begin
        response = @app.call(env)
      rescue Error
        raise # Don't capture Raven errors
      rescue Exception => e
        Raven::Rack.capture_exception(e, env)
        raise
      end

      error = env['rack.exception'] || env['sinatra.error']

      Raven::Rack.capture_exception(error, env) if error

      response
    end
  end
end
