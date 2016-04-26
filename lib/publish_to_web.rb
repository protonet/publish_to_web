# Standard Library
require 'json'
require 'logger'
require 'ostruct'
require 'socket'
require 'pathname'

# Gems
require 'net/ssh'
require 'http'
require 'rainbow'
require 'platform-skvs'

# Library
require "publish_to_web/config"
require "publish_to_web/directory"
require "publish_to_web/tunnel"
require "publish_to_web/version"

class PublishToWeb
  def self.create_logger
    Logger.new(STDOUT).tap do |logger|
      logger.level = Logger::INFO
      logger.formatter = -> (severity, datetime, progname, msg) do
        color = {
          "WARN"  => :yellow,
          "ERROR" => :red,
          "FATAL" => :red
        }[severity] || :white
        Rainbow("[#{datetime}][#{severity.ljust(5)}] #{msg}\n").color(color)
      end
    end
  end

  attr_reader :forward_port, :bind_host, :proxy_host, 
    :proxy_user, :proxy_port, :directory_host, :logger, :config

  def initialize(
      forward_port: 80, 
      bind_host: "127.0.0.1",
      proxy_host: "proxy.protonet.info",
      proxy_user: "localtunnel",
      proxy_port: 22666,
      directory_host: "https://directory.protonet.info",
      config: Config.new,
      logger: self.class.create_logger
    )

    @forward_port   = forward_port
    @bind_host      = bind_host
    @proxy_host     = proxy_host
    @proxy_user     = proxy_user
    @proxy_port     = proxy_port
    @directory_host = directory_host
    @config         = config
    @logger         = logger
  end

  def check_local_endpoint
    logger.info "Checking if local backend is available at #{bind_host}:#{forward_port}"
    TCPSocket.new(bind_host, forward_port).close

  rescue Errno::ECONNREFUSED => err
    logger.warn "Local backend is not available (yet?) - waiting for it to become available"
    sleep 5
    check_local_endpoint
  end

  def prepare_directory
    if node_name = config.node_name
      directory.set_node_name node_name
    end
    directory.set_version
    directory.public_key
  end

  def start_tunnel
    config.success = config.error = nil

    prepare_directory
    config.success = 'directory_configured'

    check_local_endpoint

    logger.info "Starting tunnel to #{proxy_host} as #{directory.node_name}"
    tunnel.start do
      config.success = "connection_established"
    end

  rescue Net::SSH::AuthenticationFailed => err
    logger.warn "#{err.class}: #{err}"
    logger.warn "Probably the SSH key is not deployed on the proxy server yet, retrying in a bit"

    sleep 30
    start_tunnel

  rescue PublishToWeb::Directory::HttpResponseError => err
    logger.warn "#{err.class}: #{err}"
    logger.warn "Failed to interact with directory, will try again in a bit"

    # Write out that we have an issue since the directory might refuse
    # our license, our chosen node name might be in conflict and so on
    config.success = nil
    config.error = "directory_failure.#{err.response.status.to_i}"

    sleep 30
    start_tunnel
  end

  private

    def directory
      @directory ||= Directory.new host: directory_host, logger: logger, config: config
    end

    def tunnel
      @tunnel ||= Tunnel.new proxy_host: proxy_host,
        proxy_user: proxy_user, 
        proxy_port: proxy_port,
        identity: directory.private_key,
        bind_host: bind_host, 
        remote_port: directory.remote_port,
        forward_port: forward_port,
        logger: self.class.create_logger
    end
end