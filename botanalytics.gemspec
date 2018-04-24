
Gem::Specification.new do |s|
    s.name = 'botanalytics'
    s.version = '0.2.5'
    s.date = '2018-04-22'
    s.summary = 'Tracker for bots'
    s.description = 'Analytics & engagement gem for chatbots'
    s.authors = ['Beyhan Esen']
    s.add_runtime_dependency 'concurrent-ruby', '~> 1', '>= 1.0.5'
    s.email = 'tech@botanalytics.co'
    s.files = %w(lib/botanalytics.rb lib/botanalytics/google.rb lib/botanalytics/amazon.rb lib/util/util.rb lib/botanalytics/facebook.rb lib/botanalytics/generic.rb lib/botanalytics/slack.rb)
    s.homepage = 'https://github.com/Botanalyticsco/botanalytics-ruby'
    s.license = 'MIT'
    s.required_ruby_version = '>= 1.9.3'
end