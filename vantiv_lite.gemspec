require File.expand_path('lib/vantiv_lite/version', __dir__)

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 2.2.0'

  s.name          = 'vantiv_lite'
  s.version       = VantivLite.version
  s.authors       = %w[Joshua Hansen]
  s.email         = %w[joshua@epicbanality.com]

  s.summary       = 'A Simplified Vanitiv/WorldPay (LitleOnline) API Library'
  s.description   = s.summary
  s.homepage      = 'https://github.com/binarypaladin/vantiv_lite'
  s.license       = 'MIT'

  s.files         = %w[LICENSE.txt README.md] + Dir['lib/**/*.rb']
  s.require_paths = %w[lib]

  s.add_development_dependency 'bundler',  '~> 1.16'
  s.add_development_dependency 'minitest', '~> 5'
  s.add_development_dependency 'nokogiri', '~> 1'
  s.add_development_dependency 'ox',       '~> 2'
  s.add_development_dependency 'rake',     '~> 12.3'
  s.add_development_dependency 'rubocop',  '~> 0.56'
end
