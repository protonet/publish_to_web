class PublishToWeb
  class Tunnel
    attr_reader :proxy_host, :proxy_user, :proxy_port, :identity, :bind_host, :remote_port, :forward_port, :logger

    def initialize(proxy_host:, proxy_user:, proxy_port:, identity:, bind_host:, remote_port:, forward_port:, logger:)
      @proxy_host   = proxy_host
      @proxy_user   = proxy_user
      @proxy_port   = proxy_port
      @identity     = identity
      @bind_host    = bind_host
      @remote_port  = remote_port
      @forward_port = forward_port
      @logger       = logger
    end

    def ssh_options
      @ssh_options ||= {
        keepalive: true,
        keepalive_interval: 5,
        paranoid: false,
        # ExitOnForwardFailure ??
        use_agent: false,
        user_known_hosts_file: "/dev/null",
        port: proxy_port,
        key_data: [identity],
        # We need to make another logger here because verbose: :warn
        # will change the log level on the logger - we want to keep
        # the info messages from the client in general but avoid the
        # low-level noise from net/ssh
        logger: PublishToWeb.create_logger,
        verbose: :warn
      }
    end
    
    def local_port
      server = TCPServer.new('127.0.0.1', 0)
      server.addr[1]
    ensure
      server.close
    end

    def stop
      @running = false
    end

    def running?
      @running
    end

    def start
      Net::SSH.start proxy_host, proxy_user, ssh_options do |ssh|
        ssh.forward.remote forward_port, bind_host, remote_port do |real_remote_port|
          # Indicate to our caller that we have established the connection successfully
          yield if block_given?
          logger.info "Established remote forwarding at port #{real_remote_port}"
        end

        ssh.forward.local(local_port, bind_host, 8765).tap do |real_local_port|
          logger.info "Established local forwarding at port #{real_local_port}"
        end

        logger.info "Entering keepalive loop"

        @running = true
        ssh.loop { @running }
      end
    end
  end
end