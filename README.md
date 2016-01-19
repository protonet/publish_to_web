# PublishToWeb 

[![Build Status](https://travis-ci.org/protonet/publish_to_web.svg?branch=master)](https://travis-ci.org/protonet/publish_to_web)
[![Rubygem Version](https://img.shields.io/gem/v/publish_to_web.svg)](https://rubygems.org/gems/publish_to_web)

This enables any Protonet or Experimental Platform system to get a public URL at NAME.protonet.info via the Protonet Proxy Tunnel service.

## Usage

    gem install publish_to_web
    ruby -e "require 'publish_to_web'; PublishToWeb.start"

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/protonet/publish_to_web.

