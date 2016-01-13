require 'spec_helper'

describe PublishToWeb::Tunnel do
  CONFIG = {
    proxy_host:   'proxyhost',
    proxy_user:   'someuser',
    proxy_port:   '1234',
    identity:     "SSH KEY",
    bind_host:    'local bind host',
    remote_port:  "12345",
    forward_port: '56778',
    logger:       Logger.new(STDOUT).tap {|l| l.level = Logger::ERROR }
  }
  let(:tunnel) { PublishToWeb::Tunnel.new **CONFIG }

  CONFIG.each do |setting_name, expected_value|
    describe "##{setting_name} option" do
      it "is set to given value on initialize" do
        expect(tunnel.send(setting_name)).to be == expected_value
      end
    end
  end

  describe "#local_port" do
    it "uses TCPServer to find an available local port for the check tunnel" do
      tcp_double = double('TCPServer')
      expect(tcp_double).to receive(:addr).and_return [nil, 45678]
      expect(tcp_double).to receive(:close)
      expect(TCPServer).to receive(:new).with('127.0.0.1', 0).and_return(tcp_double)

      expect(tunnel.local_port).to be == 45678
    end

    it "memoizes the local port value" do
      port = tunnel.local_port
      expect(tunnel.local_port).to be == port
    end
  end

  describe "#ssh_options" do
    it "generates the required options for Net::SSH from config" do
      expected_options = {
        keepalive_interval: 5,
        paranoid: false,
        use_agent: false,
        user_known_hosts_file: "/dev/null",
        port: tunnel.proxy_port,
        key_data: [tunnel.identity],
        logger: tunnel.logger,
        verbose: :info
      }
      expect(tunnel.ssh_options).to be == expected_options
    end
  end

  describe "#start" do
    let(:ssh_mock) do
      double(:ssh_mock, forward: ssh_forward_mock, loop: true )
    end
    let(:ssh_forward_mock) do
      double(:ssh_forward_mock, remote: true, local: true)
    end

    before :each do
      expect(Net::SSH).to receive(:start).
        with(tunnel.proxy_host, tunnel.proxy_user, tunnel.ssh_options).
        and_yield(ssh_mock)
    end

    it "sets up a remote forward on the ssh connection" do
      expect(ssh_forward_mock).to receive(:remote).
        with(tunnel.forward_port, tunnel.bind_host, tunnel.remote_port).
        and_yield(1234)

      tunnel.start
    end

    it "sets up a remote forward on the ssh connection" do
      expect(ssh_forward_mock).to receive(:local).
        with(tunnel.local_port, tunnel.bind_host, 8765).
        and_return(4567)

      tunnel.start
    end

    it "enters a keepalive-loop" do
      expect(ssh_mock).to receive(:loop)

      tunnel.start
    end
  end
end
