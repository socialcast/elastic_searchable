module ElasticSearchable
  class LogSubscriber < ActiveSupport::LogSubscriber
    def query(event)
      return unless logger.debug?

      name = '%s (%.1fms)' % ["ElasticSearchable Query", event.duration]

      params = event.payload[:query].merge event.payload[:options]
      # produces: 'query: "foo" OR "bar", rows: 3, ...'
      options = params.map{ |k, v| "#{k}: #{color(v, BOLD, true)}" }.join(', ')

      debug "  #{color(name, YELLOW, true)}  [ #{query} ]"
    end
  end

  module ControllerRuntime
    extend ActiveSupport::Concern

    protected
    def append_info_to_payload(payload)
      super
      payload[:elastic_searchable_runtime] = ElasticSearchable::LogSubscriber.runtime
    end

    module ClassMethods
      def log_process_action(payload)
        messages, elastic_searchable_runtime = super, payload[:elastic_searchable_runtime]
        messages << ("ElasticSearchable: %.1fms" % elastic_searchable_runtime.to_f) if elastic_searchable_runtime
        messages
      end
    end
  end
end
ElasticSearchable::LogSubscriber.attach_to :elastic_searchable
ActiveSupport.on_load(:action_controller) do
  include ElasticSearchable::ControllerRuntime
end
