class PublishToWeb
  class Config
    attr_reader :store
    private :store

    def self.config_attribute(name, key)
      define_method name do
        store.get key
      end

      define_method "#{name}=" do |value|
        store.set key, value
      end
    end

    def initialize(store: SKVS)
      @store = store
    end

    def enabled?
      !!store.get('ptw/enabled')
    end

    config_attribute :hardware_id, "ptw/hardware_id"
    config_attribute :license_key, "ptw/license"
    config_attribute :node_name,   "hostname"
    config_attribute :private_key, "ptw/publish_to_web_key"
    config_attribute :public_key,  "ptw/publish_to_web_key.pub"
    config_attribute :success,     "ptw/success"
    config_attribute :error,       "ptw/error"
  end
end