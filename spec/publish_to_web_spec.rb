require 'spec_helper'

describe PublishToWeb do
  let(:publish_to_web) { PublishToWeb.new }

  {
    forward_port: 80,
    bind_host: "127.0.0.1",
    proxy_host: "proxy.protonet.info",
    proxy_user: "localtunnel",
    proxy_port: 22666,
    directory_host: "https://directory.protonet.info"
  }.each do |setting_name, expected_default|
    describe "##{setting_name} option" do
      it "defaults to #{expected_default.inspect}" do
        expect(publish_to_web.send(setting_name)).to be == expected_default
      end

      it "allows passing a custom value on initialization" do
        ptw = PublishToWeb.new(**{setting_name => 'custom value'})
        expect(ptw.send(setting_name)).to be == 'custom value'
      end
    end
  end

  describe "#logger" do
    it "configures a default logger" do
      expect(publish_to_web.logger).to be_a Logger
      expect(publish_to_web.logger.level).to be == Logger::INFO
    end
  end

  describe "#config" do
    it "initializes a default config" do
      expect(publish_to_web.config).to be_a PublishToWeb::Config
    end
  end

  describe "#start_tunnel" do
    it "starts a new ssh tunnel based on the configuration" do
      directory_double = double("PublishToWeb::Directory")
      expected_directory_options = {
        host:   publish_to_web.directory_host,
        logger: publish_to_web.logger,
        config: publish_to_web.config
      }
      expect(PublishToWeb::Directory).to receive(:new).
        with(expected_directory_options).
        and_return(directory_double)

      expect(directory_double).to receive(:private_key).and_return('SSH KEY')
      expect(directory_double).to receive(:remote_port).and_return('12345')
      expect(directory_double).to receive(:node_name).and_return('lolwat')


      expected_tunnel_options = {
        proxy_host:   publish_to_web.proxy_host,
        proxy_user:   publish_to_web.proxy_user,
        proxy_port:   publish_to_web.proxy_port,
        identity:     "SSH KEY",
        bind_host:    publish_to_web.bind_host,
        remote_port:  "12345",
        forward_port: publish_to_web.forward_port,
        logger:       publish_to_web.logger
      }

      tunnel_double = double('PublishToWeb::Tunnel')
      expect(PublishToWeb::Tunnel).to receive(:new).
        with(expected_tunnel_options).
        and_return(tunnel_double)
      expect(tunnel_double).to receive(:start)

      publish_to_web.start_tunnel
    end
  end
end
