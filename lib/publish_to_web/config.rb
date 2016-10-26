class PublishToWeb
  class Config
    attr_reader :store
    private :store

    def self.config_attribute(name, key)
      define_method name do
        store.get key
      end

      define_method "#{name}=" do |value|
        if value.nil?
          store.del key
        else
          store.set key, value
        end
      end
    end

    def initialize(store: SKVS)
      @store = store
    end

    def enabled?
      !!store.get('ptw/control/enabled')
    end

    config_attribute :hardware_id, "ptw/hardware_id"
    config_attribute :license_key, "ptw/license"
    config_attribute :node_name,   "ptw/node_name"
    config_attribute :private_key, "ptw/publish_to_web_key_private"
    config_attribute :public_key,  "ptw/publish_to_web_key_public"
    config_attribute :success,     "ptw/success"
    config_attribute :error,       "ptw/error"

    config_attribute :smtp_host,   "smtp/host"
    config_attribute :smtp_sender, "smtp/sender"
    config_attribute :smtp_user,   "smtp/username"
    config_attribute :smtp_pass,   "smtp/password"

    def support_identifier
      identifier = store.get('system/support_identifier')
      if identifier.kind_of?(String) and identifier.strip.length > 0
        identifier
      end
    end

    def system_version
      parts = [store.get('system/channel'), store.get('system/release_number')]
      if parts.all? {|p| p.kind_of?(String) and p.strip.length > 0 }
        parts.join("/")
      else
        "unknown"
      end
    end
  end
end