module Octopus::Model  
  def self.included(base)
    base.extend(ClassMethods)    
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def connection_proxy
      self.class.connection_proxy
    end
    
    def using(shard, &block)
      class << self
        def connection_proxy
          @@connection_proxy ||= Octopus::Proxy.new(Octopus.config())
        end

        def connection 
          if self.respond_to?(:replicated)
            self.connection_proxy().set_replicated_model(self)
          end

          self.connection_proxy()
        end

        def connected?
          self.connection_proxy().connected?
        end
      end
      
      self.reset_table_name() if self != ActiveRecord::Base && self.respond_to?(:reset_table_name)
      
      if block_given?
        older_shard = self.connection_proxy.current_shard
        self.connection_proxy.block = true
        self.connection_proxy.current_shard = shard
        begin
          yield
        ensure
          self.connection_proxy.block = false
          self.connection_proxy.current_shard = older_shard
        end
      else
        self.connection_proxy.current_shard = shard
        self.connection_proxy.using_enabled = true
        return self
      end
    end
  end

  module ClassMethods
    include InstanceMethods

    def replicated_model()
      self.cattr_accessor :replicated
    end
  end  
end

ActiveRecord::Base.send(:include, Octopus::Model)