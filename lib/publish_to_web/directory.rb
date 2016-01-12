require 'sshkey'
require 'securerandom'
require 'digest/sha1'

class PublishToWeb
  class Directory
    attr_reader :host, :key, :logger

    def initialize(host:, key:, logger:)
      @host   = host
      @key    = key
      @logger = logger
    end

    def remote_port
      info["port"] if info
    end

    def pubkey_sha1
      info["pubkey_sha1"] if info
    end

    def node_name
      info["node_name"] if info
    end

    def private_key
      identity.private_key
    end

    def public_key
      identity.ssh_public_key
    end

    def hardware_id
      "aal-#{SecureRandom.uuid}"
    end

    def version
      "platform-alpha"
    end

    def public_key_ok?
      if public_key
        Digest::SHA1.hexdigest(public_key) == pubkey_sha1
      end
    end

    def set_node_name
      response = HTTP.post url_for('set_node_name'), form: { license_key: key, node_name: node_name }
      if (200..299).include? response.status
        true
      else
        raise "Failed to set version in directory! HTTP Status #{response.status}"
      end
    end

    def create_license
      response = HTTP.get url_for('create_license'), params: { hardware_id: hardware_id }
      if (200..299).include? response.status
        JSON.parse(response.body)["license_key"]
      else
        raise "Failed to create license in directory! HTTP Status #{response.status}"
      end
    end

    def set_version
      response = HTTP.post url_for('set_version'), form: { license_key: key, version: version.shellescape }
      if (200..299).include? response.status
        true
      else
        raise "Failed to set version in directory! HTTP Status #{response.status}"
      end
    end

    def register_identity
      response = HTTP.post url_for("/set_public_key"), form: { license_key: key, public_key: public_key }
      if (200..299).include? response.status
        true
      else
        raise "Failed to register identity with directory! HTTP Status #{response.status}"
      end
    end

    private

      def identity
        @identity ||= SSHKey.generate(type: 'rsa', bits: 4096)
      end

      def info
        @info ||= begin
          logger.info "Retrieving connection info from directory #{host}"
          response = HTTP.get(url_for('/info'), params: { license_key: key })
          if response.status == 200
            JSON.load(response.body)
          else
            raise "Failed to get connection info from directory! HTTP Status #{response.status}"
          end
        end
      end

      def url_for(path)
        File.join host, path
      end
  end
end