require_relative 'botanalytics/google'
require_relative 'botanalytics/amazon'
require_relative 'botanalytics/facebook'
require_relative 'botanalytics/generic'
require_relative 'botanalytics/slack'
module Botanalytics
    AmazonAlexa = ::AmazonAlexa
    GoogleAssistant = ::GoogleAssistant
    Generic = ::Generic
    SlackRTMApi = ::SlackRTMApi
    SlackEventApi = ::SlackEventApi
    FacebookMessenger = ::FacebookMessenger
end