# Standard Library
require 'json'
require 'logger'
require 'ostruct'
require 'socket'
require 'pathname'

# Gems
require 'net/ssh'
require 'http'
require 'platform-skvs'

# Library
require "publish_to_web/config"
require "publish_to_web/directory"
require "publish_to_web/tunnel"
require "publish_to_web/version"

class PublishToWeb
  attr_reader :forward_port, :bind_host, :proxy_host, 
    :proxy_user, :proxy_port, :directory_host, :directory_key, :logger

  def initialize(
      forward_port: 80, 
      bind_host: "127.0.0.1",
      proxy_host: "proxy.protonet.info",
      proxy_user: "localtunnel",
      proxy_port: 22666,
      directory_host: "https://directory.protonet.info",
      directory_key:
    )

    @forward_port = forward_port
    @bind_host = bind_host
    @proxy_host = proxy_host
    @proxy_user = proxy_user
    @proxy_port = proxy_port
    @directory_host = directory_host
    @directory_key = directory_key
    @logger = Logger.new(STDOUT, Logger::INFO)
  end

  def start_tunnel
    logger.info "Starting tunnel to #{proxy_host} as #{directory.node_name}"
    directory.register_identity
    tunnel.start
  end

  private

    def identity
    end

    def directory
      @directory ||= Directory.new host: directory_host, key: directory_key, logger: logger
    end

    def tunnel
      @tunnel ||= Tunnel.new proxy_host: proxy_host,
        proxy_user: proxy_user, 
        proxy_port: proxy_port,
        identity: directory.private_key,
        bind_host: bind_host, 
        remote_port: directory.remote_port, 
        forward_port: forward_port,
        logger: logger
    end
end