module ElasticSearchable
  module Server
    module Java
      def self.installed?
        `java -version`
        $?.success?
      end
    end
  end
end
