require 'sshkey'
require 'securerandom'
require 'digest/sha1'
require 'shellwords'

class PublishToWeb
  class Directory
    class HttpResponseError < StandardError
      attr_reader :response
      def initialize(message, response)
        @response = response
        super "#{message} - HTTP Status: #{response.status}"
      end
    end

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
      config.system_version
    end

    def set_node_name(node_name)
      logger.info "Setting node name at directory to #{node_name}"
      response = HTTP.post url_for('set_node_name'), form: { license_key: license_key, node_name: node_name }
      if (200..299).include? response.status
        logger.info "New node name registered successfully"
        info refresh: true
        true
      else
        raise HttpResponseError.new("Failed to set new node name in directory", response)
      end
    end

    def set_version
      logger.info "Setting version at directory to #{version}"
      payload = { 
        license_key: license_key, 
        version: Shellwords.shellescape(version), 
        support_identifier: config.support_identifier 
      }
      response = HTTP.post url_for('set_version'), form: payload
      if (200..299).include? response.status
        true
      else
        raise HttpResponseError.new("Failed to set version in directory", response)
      end
    end

    def smtp_config
      logger.info "Retrieving SMTP configuration from directory"
      response = HTTP.get url_for('smtp_config'), params: { license_key: license_key }
      if (200..299).include? response.status
        JSON.parse(response.body)
      else
        raise HttpResponseError.new("Failed to retrieve smtp credentials from directory", response)
      end
    end

    def limits
      logger.info "Retrieving limits from directory"
      response = HTTP.get url_for('limits'), params: { license_key: license_key }
      if (200..299).include? response.status
        JSON.parse(response.body)
      else
        raise HttpResponseError.new("Failed to retrieve limits from directory", response)
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
        logger.info "Checking for useable SSH key pair"
        if public_key_ok?
          logger.info "The existing SSH key pair appears to be valid"
          true
        else
          logger.info "Generating new SSH key pair"
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
            raise HttpResponseError.new("Failed to get connection info from directory", response)
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
          raise HttpResponseError.new("Failed to create license in directory", response)
        end
      end

      def register_identity(new_public_key)
        logger.info "Registering new public key in directory"
        response = HTTP.post url_for("set_public_key"), form: { license_key: license_key, public_key: new_public_key }
        if (200..299).include? response.status
          logger.info "Successfully registered new public key in directory"
          true
        else
          raise HttpResponseError.new("Failed to register identity with directory", response)
        end
      end

      def url_for(path)
        File.join host, path
      end
  end
end