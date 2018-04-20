require_relative '../util/util'

# GoogleAsistant Logger
class GoogleAssistant < Envoy
  # @param params Hash
  # @raise ArgumentError When token is nil
  def initialize(params = {})
    super(params)
    @path = 'messages/google-assistant/'
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

  # @param req Hash
  # @param res Hash
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

  def validate(req, res)
    pv = is_valid(req, {}, 'request')
    unless pv[:ok]
      return pv
    end
    pv = is_valid(req, "", 'request', 'user', 'userId')
    unless pv[:ok]
      return pv
    end
    pv = is_valid(req, "", 'request', 'conversation', 'conversationId')
    unless pv[:ok]
      return pv
    end
    pv = is_valid(res, {}, 'response')
    unless pv[:ok]
      return pv
    end
    res['expectUserResponse'] ?
        is_valid(res, {}, 'response', 'finalResponse'):
        is_valid(res, [], 'response', 'expectedInputs')

  end
  private :validate
end
