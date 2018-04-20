require_relative '../util/util'

# Amazon Alexa Logger
class AmazonAlexa < Envoy
    # @param params Hash
    # @raise ArgumentError When token is nil
    def initialize(params = {})
        super(params)
        @path = 'messages/amazon-alexa/'
        @async = params.fetch(:async, false)
        informs("Logging enabled for #{self.class.name}...")
        if @async
            require 'concurrent'
            @executor_service = Concurrent::ThreadPoolExecutor.new(
                min_threads: 1,
                max_threads: Concurrent.processor_count,
                max_queue: 100,
                fallback_policy: :caller_runs
            )
            informs("Mode: Async...")
        end
    end

    def log(req, res)
        validation = validate(req, res)
        if validation[:ok]
            payload = {:request => req, :response => res}
            informs("Logging messages...")
            informs(payload)
            if @async
                @executor_service.post do
                    submits(payload, @path)
                end
            else
                submits(payload, @path)
            end
        else
            fails(validation[:err], validation[:reason], {:request => req, :response => res})
        end
    end
    # @param req Hash
    # @param res Hash
    # @return Hash
    def validate(req, res)
        pv = is_valid(req, {}, 'request')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(req, {}, 'request', 'request')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(req, "", 'request', 'context', 'System', 'user', 'userId')
        unless pv[:ok]
            return pv
        end
        pv = is_valid(res, {}, 'response')
        unless pv[:ok]
            return pv
        end
        is_valid(res, {}, 'response', 'response')
    end
    private :validate
end