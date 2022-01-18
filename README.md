# VantivLite

## Overview

This gem provides a simple interface for interacting with Vantiv's (WorldPay) LitleOnline eCommerce API. There's no real modeling. It's just a convenient way to configure your environment, send requests, and receive responses in hashes without all the mess of dealing with XML. As such, it should work with any API request available.

### Why not just use [LitleOnline](https://github.com/Vantiv/litle-sdk-for-ruby), the official SDK?

There are a number of reasons for creating this gem, despite the fact that an official Ruby implementation already exists. LitleOnline's code not particularly idiomatic Ruby. It's unlikely the developers are experienced Rubyists. That wouldn't be a show-stopper in and of itself, but the dependencies imposed by the gem are downright painful:

1. [`libxml-ruby`](https://github.com/xml4r/libxml-ruby): A large library that requires an even larger native extension. Given the nature and size of the XML being generated, this is overkill unless you're already using `libxml-ruby` (and odds are you're not).
2. [`xml-object`](https://github.com/burke/xml-object): In addition to being abandoned at this point, it has a dependency of [`ActiveSupport`](https://github.com/rails/rails/tree/master/activesupport)

There are no requirements outside the standard library for this gem, although you can optionally use [Nokogiri](https://github.com/sparklemotion/nokogiri) or [Ox](https://github.com/ohler55/ox) for parsing/serializing XML.

## Installation

Pretty standard gem stuff.

    $ gem install vantiv_lite

When using [Bundler](https://bundler.io) or requiring this library in general, it's important to note that this gem will attempt to load its XML add-ons by default if `Ox` or `Nokogiri` is already defined, it will use them in that order. Otherwise, it will use the default of `REXML`. The only consideration is that `REXML` will get required if neither optional library is already required.

So, ensure you load your project's XML libs (if you're using them) first.

## Configuration

Out of the proverbial box, this should Just Work™ with Vantiv's (WorldPay) test environment using version 8.22 of the API. Obviously, when you go to production, that's probably not ideal. There are a number of ways to configure this gem.

If you're integrating into a system that's using a single configuration---pretty common to just process credit cards for your institution---you can use a global configuration set either programmatically or via environment variables:

**Note:** It's unlikely you're using version 8.22. In fact, versions can be a sticky issue with this API. Ensure you're using the version that has been assigned to you! You don't want to do all your testing in the default 8.22 only to find out you're on the latest when you move to `prelive`.

### Programmatically

```ruby
VantivLite.configure do
  env          'sandbox'
  merchant_id  'default'
  password     'sandbox'
  proxy_url    'http://user:passsword@proxy.internal:8888'
  report_group 'Default Report Group'
  username     'sandbox'
  version      '8.22'
  xml_lib      'REXML'
end
```

Note: All values displayed above are the default values, with the exception of `proxy_url` which is `nil` by default. (There's a good chance you'll need to set `proxy_url` in `prelive` and `postlive` environments since they are IP-whitelisted.)

### `ENV`

Prefix any configuration option with `vantiv_` and it will be automatically set:

* `ENV['vantiv_env']`
* `ENV['vantiv_merchant_id']`
* `ENV['vantiv_password']`
* `ENV['vantiv_proxy_url']`
* `ENV['vantiv_report_group']`
* `ENV['vantiv_username']`
* `ENV['vantiv_version']`
* `ENV['vantiv_xml_lib']`

You can return the configuration set by the environment with `VantivLite.env_config` which might be useful in situations where you want multiple configurations modified from a default set by the environment.

### Multiple Configurations

If you're building a platform that allows multiple clients to plug into Vantiv's API with their own credentials, IDs, or whatever else you'll need to use different configuration options for each. This is done by creating `VantivLite::Config` objects and injecting them into requests. (The global default is used by default in new requests.)

This can be done with an existing config:

```ruby
config = VantivLite.env_config
new_config = config.with(username: 'user', password: 'password2')
```

Or by just creating a new one:

```ruby
# With a hash:

config = VantivLite::Config.new(env: 'prelive' version: '11.1')

# With DSL:

config = VantivLite::Config.build
  proxy_url 'http://proxy.internal:8888'
  xml_lib 'Ox'
end
```

## Making Requests

A basic request can be made using `VantivLite.request`. This uses the global config and request objects:

```ruby
params = {
  'registerTokenRequest' => {
    'orderId' => '50',
    'accountNumber' => '4457119922390123'
  }
}

response = VantivLite.request(params) # => #<VantivLite::Response>
```

This will return a `VantivLite::Response` which itself operates much like a hash:

```ruby
response.dig('registerTokenResponse', 'litleToken') # => "1111222233330123"
```

For many simple transactions the `*_request` and `*_response` keys get a little tedious. So, this can be abbreviated to the following:

```ruby
params = {
  'orderId' => '50',
  'accountNumber' => '4457119922390123'
}

response = VantivLite.register_token(params).dig('litleToken') # => "1111222233330123"
```

There are shortcuts for the requests:

  * `auth_reversal`
  * `authorization`
  * `capture`
  * `credit`
  * `register_token`
  * `sale`
  * `void`

### Requests With Multiple Configurations

`VantiveLite.request` (and the various convenience versions) simply uses `Vantiv.default_request` which is just an instance of `VantivLite::Request`. The request object itself can be used similarly with the methods by invoking `#call`:

```ruby
params = {
  'registerTokenRequest' => {
    'orderId' => '50',
    'accountNumber' => '4457119922390123'
  }
}

response = VantivLite::Request.new(custom_config).(params) # => #<VantivLite::Response>

# Shortcut methods also work:

params = {
  'orderId' => '50',
  'accountNumber' => '4457119922390123'
}

response = VantivLite::Request.new(custom_config).register_token(params)
```

### Elements and Attributes

Obviously, XML doesn't map nice and neat to a hash and vice-versa. However, Vantiv's API doesn't make heavy use of attributes so, on serialization, certain keys are serialized into attributes and return hashes just merge everything together. For example, if you wanted to set an `id` attribute, you would do the following:

```ruby
params = {
  'registerTokenRequest' => {
    'id' => 'abcdef',
    'orderId' => '50',
    'accountNumber' => '4457119922390123'
  }
}
```

See `VantivLite::XML::Serializer` for a list of defaults.

### Order Matters

This library does not use any sort of models and the mapping done is purely to rename keys into something more "Ruby-ish." Unfortunately, the API XML XSDs from Vantiv are relatively picky. Your hash keys should be in the same order they appear in the documentation.

If you get an error like this:

```
VantivLite::Response::ServerError: Error validating xml data against the schema cvc-complex-type.2.4.a: Invalid content was found starting with element 'orderId'. One of '{"http://www.litle.com/schema":cardValidationNum}' is expected.
```

It probably means your keys are out of order.

Yes, this could be solved by consuming the XSDs and validating requests or modeling every single object. However, the overhead probably isn't worth it and can require version specific changes. Developers are just going to wrap these lower level calls in their own objects anyway where order can be enforced as necessary.

## Vantiv Environments

Valid environments are:

* `sandbox`
* `prelive`
* `postlive`

This configures the API url. At the moment, that's really all it does.

## Reports

Need access to reports? Turns out, there's a [separate gem for that](https://github.com/binarypaladin/vantiv_sftp_reports).

## Contributing

### Issue Guidelines

GitHub issues are for bugs, not support. As of right now, there is no official support for this gem. You can try reaching out to the author, [Joshua Hansen](mailto:joshua@epicbanality.com?subject=VantivLite) if you're really stuck, but there's a pretty high chance that won't go anywhere at the moment or you'll get a response like this:

> Hi. I'm super busy. It's nothing personal. Check the README first if you haven't already. If you don 't find your answer there, it's time to start reading the source. Have fun! Let me know if I screwed something up.

### Pull Request Guidelines

* Include tests with your PRs.
* Run `rubocop` to ensure your style fits with the rest of the project.

### Code of Conduct

Be nice. After all, this is free code. I have a day job.

## License

See [`LICENSE.txt`](LICENSE.txt).

## What if I stop maintaining this?

The codebase isn't huge. If you opt to rely on this code and I die/get bored/find enlightenment you should be able to maintain it. Sadly, that's the only guarantee at the moment!
