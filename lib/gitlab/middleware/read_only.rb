module Gitlab
  module Middleware
    class ReadOnly
      DISALLOWED_METHODS = %w(POST PATCH PUT DELETE).freeze
      APPLICATION_JSON = 'application/json'.freeze
      API_VERSIONS = (3..4)

      def initialize(app)
        @app = app
        @whitelisted = internal_routes
      end

      def call(env)
        @env = env

        if disallowed_request? && Gitlab::Database.read_only?
          Rails.logger.debug('GitLab ReadOnly: preventing possible non read-only operation')
          error_message = 'You cannot do writing operations on a read-only GitLab instance'

          if json_request?
            return [403, { 'Content-Type' => 'application/json' }, [{ 'message' => error_message }.to_json]]
          else
            rack_flash.alert = error_message
            rack_session['flash'] = rack_flash.to_session_value

            return [301, { 'Location' => last_visited_url }, []]
          end
        end

        @app.call(env)
      end

      private

      def internal_routes
        API_VERSIONS.flat_map { |version| "api/v#{version}/internal" }
      end

      def disallowed_request?
        DISALLOWED_METHODS.include?(@env['REQUEST_METHOD']) && !whitelisted_routes
      end

      def json_request?
        request.media_type == APPLICATION_JSON
      end

      def rack_flash
        @rack_flash ||= ActionDispatch::Flash::FlashHash.from_session_value(rack_session)
      end

      def rack_session
        @env['rack.session']
      end

      def request
        @env['rack.request'] ||= Rack::Request.new(@env)
      end

      def last_visited_url
        @env['HTTP_REFERER'] || rack_session['user_return_to'] || Rails.application.routes.url_helpers.root_url
      end

      def route_hash
        @route_hash ||= Rails.application.routes.recognize_path(request.url, { method: request.request_method }) rescue {}
      end

      def whitelisted_routes
        logout_route || grack_route || @whitelisted.any? { |path| request.path.include?(path) } || lfs_route || sidekiq_route
      end

      def logout_route
        route_hash[:controller] == 'sessions' && route_hash[:action] == 'destroy'
      end

      def sidekiq_route
        request.path.start_with?('/admin/sidekiq')
      end

      def grack_route
        request.path.end_with?('.git/git-upload-pack')
      end

      def lfs_route
        request.path.end_with?('/info/lfs/objects/batch')
      end
    end
  end
end