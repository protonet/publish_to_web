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
        public_key: 'foobar',
        smtp_config: {
          "host"     => 'smtp.example.com', 
          "sender"   => 'noreply@example.com', 
          "user"     => 'theusername', 
          "password" => 'thepassword' 
        },
        limits: { "accounts" => 5 },
        report_usage: nil

      expect(PublishToWeb::Directory).to receive(:new).
        and_return(directory_double)

      directory_double
    end

    it "sets the node_name in directory if configured locally" do
      allow(directory_double).to receive(:node_name).and_return('other-name')
      expect(directory_double).to receive(:set_node_name).with('lolwat')

      publish_to_web.config.node_name = 'lolwat'
      publish_to_web.prepare_directory
    end

    it "does not set the node_name in directory same as local" do
      allow(directory_double).to receive(:node_name).and_return('lolwat')
      expect(directory_double).not_to receive(:set_node_name).with('lolwat')

      publish_to_web.config.node_name = 'lolwat'
      publish_to_web.prepare_directory
    end

    it "does not set node name in directory if not configured locally" do
      expect(directory_double).not_to receive(:set_node_name)

      publish_to_web.prepare_directory
    end

    describe "SMTP configuration" do
      before(:each) do
        expect(directory_double).to receive(:smtp_config).and_return(
          "host"     => 'smtp.example.com', 
          "sender"   => 'noreply@example.com', 
          "user"     => 'theusername', 
          "password" => 'thepassword' 
        )
      end

      it "sets smtp host based on directory" do
        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.smtp_host
        }.from(nil).to('smtp.example.com')
      end

      it "sets smtp sender based on directory" do
        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.smtp_sender
        }.from(nil).to('noreply@example.com')
      end

      it "sets smtp user based on directory" do
        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.smtp_user
        }.from(nil).to('theusername')
      end

      it "sets smtp password based on directory" do
        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.smtp_pass
        }.from(nil).to('thepassword')
      end
    end

    describe "limits" do
      it "sets accounts limit based on directory" do
        expect(directory_double).to receive(:limits).and_return(
          "accounts" => 5
        )

        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.account_limit
        }.from(nil).to("5")
      end

      it "drops accounts limit based on directory" do
        publish_to_web.config.account_limit = "5"

        expect(directory_double).to receive(:limits).and_return(
          "accounts" => nil
        )

        expect { publish_to_web.prepare_directory }.to change {
          publish_to_web.config.account_limit
        }.from("5").to(nil)
      end
    end

    it "reports usage to directory" do
      expect(directory_double).to receive(:report_usage)

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
      directory_double = double("PublishToWeb::Directory", 
        smtp_config: {}, 
        limits: {},
        report_usage: nil
      )
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

      # Initially the status should be reset
      expect(publish_to_web.config).to receive(:success=).with(nil)
      expect(publish_to_web.config).to receive(:error=).with(nil)
      # Afterwards, we write separate success messages: One when the directory is configured,
      # the other once we are fully connected
      expect(publish_to_web.config).to receive(:success=).with('directory_configured')
      expect(publish_to_web.config).to receive(:success=).with('connection_established')

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
      allow(tunnel_double).to receive(:running?).
        and_return false

      publish_to_web.start_tunnel
    end

    it "retries to establish the tunnel if SSH authentication fails" do
      expect(PublishToWeb::Directory).to receive(:new).
        and_return(
          double('directory', 
            node_name: 'foo', 
            private_key: 'foo', 
            remote_port: 123,
            set_version: true,
            public_key: "foobar",
            smtp_config: {},
            limits: {},
            report_usage: nil
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

    it "checks connectivity to the local endpoint" do
      expect(PublishToWeb::Directory).to receive(:new).
        and_return(
          double('directory',
            node_name: 'foo', 
            private_key: 'foo', 
            remote_port: 123,
            set_version: true,
            public_key: "foobar",
            smtp_config: {},
            limits: {},
            report_usage: nil
          )
        )
      expect(publish_to_web).to receive(:check_local_endpoint).and_return(true)

      expect(PublishToWeb::Tunnel).to receive(:new).and_return(OpenStruct.new(start: nil))
      publish_to_web.start_tunnel
    end

    it "handles failures to interact with the directory gracefully" do
      error     = PublishToWeb::Directory::HttpResponseError.new 'Message', OpenStruct.new(status: 403)
      directory = double :directory, set_version: true, public_key: true,
        node_name: 'archimedes'

      allow(directory).to receive(:set_node_name).and_raise error
      allow(publish_to_web).to receive(:directory).and_return directory

      allow(publish_to_web.config).to receive(:node_name).and_return 'carla'
      allow(publish_to_web.config).to receive(:error=).with nil

      expect(publish_to_web.config).to receive(:error=).with('directory_failure.403')

      publish_to_web.prepare_directory
    end
  end
end
