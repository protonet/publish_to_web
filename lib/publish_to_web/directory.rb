require 'sshkey'
require 'securerandom'
require 'digest/sha1'

class PublishToWeb
  class Directory
    class HttpResponseError < StandardError; end;

    attr_reader :host, :config, :logger

    def initialize(host:, config:, logger:)
      @host   = host
      @config = config
      @logger = logger
    end

    def remote_port
      info["port"] if info
    end

    def directory_public_key_sha1
      info["pubkey_sha1"] if info
    end

    def node_name
      info["node_name"] if info
    end

    def private_key
      ensure_valid_identity!
      config.private_key
    end

    def public_key
      ensure_valid_identity!
      config.public_key
    end

    # Returns the stored hardware_id or generates a new one
    def hardware_id
      config.hardware_id ||= "aal-#{SecureRandom.uuid}"
    end

    # Returns the stored license_key or requests a new one
    def license_key
      config.license_key ||= create_license_key
    end

    def version
      "platform-alpha"
    end

    def set_node_name(node_name)
      logger.info "Setting node name at directory to #{node_name}"
      response = HTTP.post url_for('set_node_name'), form: { license_key: license_key, node_name: node_name }
      if (200..299).include? response.status
        logger.info "New node name registered successfully"
        info refresh: true
        true
      else
        raise HttpResponseError, "Failed to set new node name in directory! HTTP Status #{response.status}"
      end
    end

    def set_version
      logger.info "Setting version at directory to #{version}"
      response = HTTP.post url_for('set_version'), form: { license_key: license_key, version: version.shellescape }
      if (200..299).include? response.status
        true
      else
        raise HttpResponseError, "Failed to set version in directory! HTTP Status #{response.status}"
      end
    end

    private

      def public_key_ok?
        if config.public_key and config.private_key
          SSHKey.new(config.private_key).ssh_public_key == config.public_key &&
            Digest::SHA1.hexdigest(config.public_key) == directory_public_key_sha1
        end
      end

      def ensure_valid_identity!
        if public_key_ok?
          true
        else
          SSHKey.generate(type: 'rsa', bits: 4096).tap do |new_identity|
            register_identity new_identity.ssh_public_key
            info refresh: true

            config.private_key = new_identity.private_key
            config.public_key  = new_identity.ssh_public_key
          end
          true
        end
      end

      def info(refresh: false)
        @info = nil if refresh

        @info ||= begin
          logger.info "Retrieving connection info from directory #{host}"
          response = HTTP.get(url_for('info'), params: { license_key: license_key })
          if response.status == 200
            JSON.load(response.body)
          else
            raise HttpResponseError, "Failed to get connection info from directory! HTTP Status #{response.status}"
          end
        end
      end

      def create_license_key
        logger.info "Creating a new license key in directory"
        response = HTTP.get url_for('create_license'), params: { hardware_id: hardware_id }
        if (200..299).include? response.status
          logger.info "Successfully created new license key"
          JSON.parse(response.body)["license_key"]
        else
          raise HttpResponseError, "Failed to create license in directory! HTTP Status #{response.status}"
        end
      end

      def register_identity(new_public_key)
        logger.info "Registering new public key in directory"
        response = HTTP.post url_for("set_public_key"), form: { license_key: license_key, public_key: new_public_key }
        if (200..299).include? response.status
          logger.info "Successfully registered new public key in directory"
          true
        else
          raise HttpResponseError, "Failed to register identity with directory! HTTP Status #{response.status}"
        end
      end

      def url_for(path)
        File.join host, path
      end
  end
end