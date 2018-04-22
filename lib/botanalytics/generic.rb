require_relative "../util/util"

# Generic Logger
class Generic < Envoy
    # @param params Hash
    # @raise ArgumentError When token is nil
    def initialize(params = {})
        super(params)
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
    def log(message)
        validation = validate(message)
        if validation[:ok]
            informs("Logging messages...")
            informs(message)
            if @async
                @executor_service.post do
                    submits(message)
                end
            else
                submits(message)
            end
        else
            fails(validation[:err], validation[:reason], message)
        end
    end
    # @param payload Hash
    def validate(payload)
        pv = is_valid(payload, {}, 'payload')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(payload, Object.new, 'payload', 'is_sender_bot')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(payload, "", 'payload', 'user', 'id')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(payload, "", 'payload', 'user', 'name')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(payload, "", 'payload', 'message', 'text')
        unless pv[:ok]
            return pv
        end
        is_valid(payload, 1, 'payload', 'message', 'timestamp')
    end
    private :validate
end
