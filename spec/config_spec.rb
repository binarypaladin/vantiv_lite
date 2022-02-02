require_relative 'spec_helper'

module VantivLite
  class ConfigSpec < Minitest::Spec
    let(:config_hash) do
      {
        env:          'prelive',
        merchant_id:  '5555',
        password:     'password123',
        proxy_url:    'http://user:passsword@proxy.internal:8888',
        report_group: 'Custom Report Group',
        username:     'staging',
        version:      '11.1',
        xml_lib:      'REXML'
      }
    end

    def check_keys(config)
      config_hash.each { |k, v| _(config.public_send(k)).must_equal(v) }
    end

    it 'provides a default sandbox config' do
      config = Config.new
      assert config.sandbox?
      %i[merchant_id password username].each { |k| assert config.public_send(k) }
    end

    it 'does not set credentials for non-sandox configs' do
      config = Config.new(env: 'prelive')
      %i[merchant_id password username].each { |k| refute config.public_send(k) }
    end

    it 'can be configure with a hash' do
      config = Config.new(config_hash)
      check_keys(config)

      _(config.uri).must_equal(Config::ENVS[config.env])
      _(config.uri).must_be_instance_of(URI::HTTPS)

      _(config.proxy_uri.to_s).must_equal(config.proxy_url)
      _(config.proxy_uri).must_be_instance_of(URI::HTTP)
    end

    it 'can be configured programatically' do
      opts = config_hash

      config = Config.build do
        env          opts[:env]
        merchant_id  opts[:merchant_id]
        password     opts[:password]
        proxy_url    opts[:proxy_url]
        report_group opts[:report_group]
        username     opts[:username]
        version      opts[:version]
        xml_lib      opts[:xml_lib]
      end

      check_keys(config)
    end

    it 'can create a new config from an existing config' do
      config = Config.new(env: 'postlive')
      refute config.sandbox?
      refute config.password
      _(config.version).must_equal('8.22')

      new_config = config.with(env: 'sandbox', version: '12.0')
      assert new_config.sandbox?
      assert new_config.password
      _(new_config.version).must_equal('12.0')

      %i[report_group xml_lib].each do |k|
        _(new_config.public_send(k)).must_equal(config.public_send(k))
      end
    end

    it 'creates a config object from ENV' do
      ENV['vantiv_username'] ||= 'env_user'
      _(VantivLite.env_config.username).must_equal(ENV['vantiv_username'])
    end
  end
end
