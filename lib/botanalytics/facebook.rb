require_relative "../util/util"

require_relative '../util/util'

# Facebook Logger
class FacebookMessenger < Envoy
    # @param params Hash
    # @raise ArgumentError When token is nil
    def initialize(params = {})
        super(params)
        @fb_token = params.fetch(:fb_token, nil)
        @path = 'messages/facebook-messenger/'
        @profile_path = 'facebook-messenger/users/'
        @async = params.fetch(:async, false)
        informs("Logging enabled for #{self.class.name}...")
        if @async
            require 'concurrent'
            @executor_service = Concurrent::ThreadPoolExecutor.new(
                min_threads: 1,
                max_threads: Concurrent.processor_count * 2,
                max_queue: Concurrent.processor_count * 1000,
                fallback_policy: :caller_runs
            )
            informs("Mode: Async...")
        end
    end
    # @param message Hash
    def log_incoming(message)
        validation = validate(message, "Incoming message")
        if validation[:ok]
            payload = {
                'recipient': nil,
                'timestamp': (Time.new.to_f*1000).to_i,
                'message': message
            }
            informs("Logging incoming message...")
            informs(message)
            if @async
                @executor_service.post do
                    submits(payload, @path)
                end
            else
                submits(payload, @path)
            end
        else
            fails(validation[:err], validation[:reason], message)
        end
    end
    # @param message Hash
    # @param sender_id String
    def log_outgoing(message, sender_id)
        validation = validate_outgoing(message, sender_id)
        if validation[:ok]
            payload = {
                'recipient': sender_id,
                'timestamp': (Time.new.to_f*1000).to_i,
                'message': message,
                'fb_token': @fb_token
            }
            informs("Logging outgoing message...")
            informs(message)
            if @async
                @executor_service.post do
                    submits(payload, @path)
                end
            else
                submits(payload, @path)
            end
        else
            fails(validation[:err], validation[:reason], message)
        end
    end

    # @param message Hash
    def log_user_profile(message)
        validation = validate(message, "User profile")
        if validation[:ok]
            informs("Logging user profile message...")
            informs(message)
            if @async
                @executor_service.post do
                    submits(message, @profile_path)
                end
            else
                submits(message, @profile_path)
            end
        else
            fails(validation[:err], validation[:reason], message)
        end
    end

    def validate(payload, name)
        is_valid(payload, {}, name)
    end

    def validate_outgoing(message, sender_id)
        mv = is_valid(message, {}, "Outgoing message")
        unless mv[:ok]
            return mv
        end
        is_valid(sender_id, "", "Sender id")
    end

    private :validate
    private :validate_outgoing
end
