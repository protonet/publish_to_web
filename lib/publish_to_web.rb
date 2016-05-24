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

  rescue Errno::ECONNREFUSED
    logger.warn "Local backend is not available (yet?) - waiting for it to become available"
    sleep 5
    check_local_endpoint
  end

  SLD = Regexp.escape '.protonet.info'
  def prepare_directory(fail_gracefully = true)
    config.success = config.error = nil

    if node_name = config.node_name
      if /^#{ Regexp.escape node_name }(#{ SLD })?$/ !~ directory.node_name
        directory.set_node_name node_name
      end
    end
    directory.set_version
    directory.public_key

    config.success = 'directory_configured'
  rescue PublishToWeb::Directory::HttpResponseError => err
    logger.warn "#{err.class}: #{err}"
    logger.warn "Failed to interact with directory, will try again in a bit"

    # Write out that we have an issue since the directory might refuse
    # our license, our chosen node name might be in conflict and so on
    config.error = "directory_failure.#{err.response.status.to_i}"

    raise unless fail_gracefully
  end

  def stop_tunnel(*join_args)
    tunnel.stop
    @thread.try :join, *join_args
  end

  def start_tunnel(blocking: true)
    unless blocking
      @thread = Thread.new { start_tunnel blocking: true }
      @thread.abort_on_exception = true
      return
    end

    prepare_directory false
    check_local_endpoint

    logger.info "Starting tunnel to #{proxy_host} as #{directory.node_name}"
    begin
      tunnel.start { config.success = "connection_established" }
    end while tunnel.running? and sleep(5)

  rescue Net::SSH::AuthenticationFailed => err

    logger.warn "#{err.class}: #{err}"
    logger.warn "Probably the SSH key is not deployed on the proxy server yet, retrying in a bit"

    sleep 30
    retry

  rescue PublishToWeb::Directory::HttpResponseError

    # already handled by #prepare_directory, we just need to wait and retry...

    sleep 30
    retry

  rescue => error

    logger.error error

  end

  private

    def directory
      @directory ||= Directory.new host: directory_host, logger: logger, config: config
    end

    def tunnel
      @tunnel ||= Tunnel.new proxy_host: proxy_host,
        proxy_user:   proxy_user, 
        proxy_port:   proxy_port,
        identity:     directory.private_key,
        bind_host:    bind_host, 
        remote_port:  directory.remote_port,
        forward_port: forward_port,
        logger:       self.class.create_logger
    end
end
