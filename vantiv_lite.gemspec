require File.expand_path('lib/vantiv_lite/version', __dir__)

WORLD_PAY_MINI_GEMSPEC = Gem::Specification.new do |s|
  s.required_ruby_version = '>= 2.2.0'

  s.name          = 'vantiv_lite'
  s.version       = VantivLite.version
  s.authors       = %w[Joshua Hansen]
  s.email         = %w[joshua@epicbanality.com]

  s.summary       = 'Simplified Vanitiv/WorldPay eComm (LitleOnline) API'
  s.description   = 'LitleOnline transactions without dependencies.'
  s.homepage      = 'https://github.com/binarypaladin/vantiv_lite'
  s.license       = 'MIT'

  s.files         = %w[CONTRIBUTING.md LICENSE.txt README.md Rakefile] +
                    Dir['{spec,lib}/**/*.{rb,RB}']
  s.require_paths = %w[lib]

  s.add_development_dependency 'bundler',  '~> 1.16'
  s.add_development_dependency 'minitest', '~> 5.0'
  s.add_development_dependency 'nokogiri', '~> 1.8'
  s.add_development_dependency 'ox',       '~> 2.9'
  s.add_development_dependency 'rake',     '~> 10.0'
  s.add_development_dependency 'rubocop',  '~> 0.56'
end
