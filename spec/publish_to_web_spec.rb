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

  describe "#check_local_endpoint" do
    it "tries to open a local connection to the backend" do
      # Ensure we wait for a bit before we retry the connect
      expect(publish_to_web).to receive(:sleep).with(5)

      calls = 0
      # On first tunnel start throw the connection exception to verify we retry
      # (and then succeed)
      expect(TCPSocket).to receive(:new).
        twice do
          calls += 1
          if calls == 1
            raise Errno::ECONNREFUSED
          else
            OpenStruct.new(close: true)
          end
        end

      publish_to_web.check_local_endpoint
    end
  end

  describe "#prepare_directory" do
    let(:directory_double) do
      directory_double = double "PublishToWeb::Directory", 
        set_node_name: true, 
        set_version: true,
        public_key: 'foobar'

      expect(PublishToWeb::Directory).to receive(:new).
        and_return(directory_double)

      directory_double
    end

    it "sets the node_name in directory if configured locally" do
      expect(directory_double).to receive(:set_node_name).with('lolwat')

      publish_to_web.config.node_name = 'lolwat'
      publish_to_web.prepare_directory
    end

    it "does not set node name in directory if not configured locally" do
      expect(directory_double).not_to receive(:set_node_name)

      publish_to_web.prepare_directory
    end

    it "sends version to directory" do
      expect(directory_double).to receive(:set_version)

      publish_to_web.prepare_directory
    end

    it "requests the public key to ensure we have a valid identity registered" do
      expect(directory_double).to receive(:public_key)

      publish_to_web.prepare_directory
    end
  end

  describe "#start_tunnel" do
    before(:each) do
      # Stub our local connection check
      allow(TCPSocket).to receive(:new).
        with(publish_to_web.bind_host, publish_to_web.forward_port).
        and_return OpenStruct.new(close: true)
    end

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
      expect(directory_double).to receive(:set_version).and_return(true)
      expect(directory_double).to receive(:public_key).and_return("akey")


      expected_tunnel_options = {
        proxy_host:   publish_to_web.proxy_host,
        proxy_user:   publish_to_web.proxy_user,
        proxy_port:   publish_to_web.proxy_port,
        identity:     "SSH KEY",
        bind_host:    publish_to_web.bind_host,
        remote_port:  "12345",
        forward_port: publish_to_web.forward_port,
        logger:       kind_of(Logger)
      }

      tunnel_double = double('PublishToWeb::Tunnel')
      expect(PublishToWeb::Tunnel).to receive(:new).
        with(expected_tunnel_options).
        and_return(tunnel_double)
      expect(tunnel_double).to receive(:start).
        and_yield

      publish_to_web.start_tunnel

      expect(publish_to_web.config.success).to be == "connection_established"
    end

    it "retries to establish the tunnel if SSH authentication fails" do
      expect(PublishToWeb::Directory).to receive(:new).
        and_return(
          double('directory', 
            node_name: 'foo', 
            private_key: 'foo', 
            remote_port: 123,
            set_version: true,
            public_key: "foobar"
          )
        )

      # We don't really want to wait 30 seconds here ;)
      expect(publish_to_web).to receive(:sleep).
        with(30).
        and_return(true)
        
      calls = 0
      # On first tunnel start throw the auth exception to verify we retry
      # (and then succeed)
      expect(PublishToWeb::Tunnel).to receive(:new).
        twice do
          calls += 1
          if calls == 1
            raise Net::SSH::AuthenticationFailed
          else
            OpenStruct.new(start: 'foo')
          end
        end

      publish_to_web.start_tunnel
    end

    it "retries to establish the tunnel if local backend fails" do
      expect(PublishToWeb::Directory).to receive(:new).
        and_return(
          double('directory', 
            node_name: 'foo', 
            private_key: 'foo', 
            remote_port: 123,
            set_version: true,
            public_key: "foobar"
          )
        )

      calls = 0
      # On first tunnel start throw the connection exception to verify we retry
      # (and then succeed)
      expect(PublishToWeb::Tunnel).to receive(:new).
        twice do
          calls += 1
          if calls == 1
            raise Errno::ECONNREFUSED
          else
            OpenStruct.new(start: 'foo')
          end
        end

      publish_to_web.start_tunnel
    end

    it "handles failures to interact with the directory gracefully" do
      expect(PublishToWeb::Directory).to receive(:new).
        and_return(
          double('directory', 
            node_name: 'foo', 
            private_key: 'foo', 
            remote_port: 123,
            set_version: true,
            public_key: "foobar"
          )
        )

      # We don't really want to wait 30 seconds here ;)
      expect(publish_to_web).to receive(:sleep).
        with(30).
        and_return(true)

      # Ensure we set the error message
      expect(publish_to_web.config).to receive(:error=).with(nil).twice
      expect(publish_to_web.config).to receive(:error=).with("directory_failure.403")

      calls = 0
      # On first tunnel start throw the connection exception to verify we retry
      # (and then succeed)
      expect(PublishToWeb::Tunnel).to receive(:new).
        twice do
          calls += 1
          if calls == 1
            raise PublishToWeb::Directory::HttpResponseError.new("Message", OpenStruct.new(status: 403))
          else
            OpenStruct.new(start: 'foo')
          end
        end

      publish_to_web.start_tunnel
    end
  end
end
