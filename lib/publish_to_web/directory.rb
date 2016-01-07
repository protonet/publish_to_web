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

    private

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