module ElasticSearchable
  module AdminIndexVersions

    # creates an index to store a new index version. Returns its name
    def create_index_version(index, create_options)
      index_with_timestamp = "#{index}_#{Time.now.to_f}"
      ElasticSearchable.searcher.create_index(index_with_timestamp, create_options)
      return index_with_timestamp
    end
    
    # returns the full index name of the current version for this index
    def current_index_version(index)
      ElasticSearchable.searcher.index_status(index)["indices"].keys.first rescue nil
    end
    
    # "deploys" a new version as the current one
    def deploy_index_version(index, new_version)
      ElasticSearchable.searcher.refresh(new_version)
      if current_version = current_index_version(index)
        ElasticSearchable.searcher.alias_index(
          :add => {new_version => index}, 
          :remove => {current_version => index}
        )
      else
        ElasticSearchable.searcher.alias_index(:add => {new_version => index})
      end
    end

    # deletes all index versions older than the current one
    def prune_index_versions(index)
      puts index
      current_version = current_index_version(index)
      return unless current_version
      old_versions = index_versions(index).select{|version| version_timestamp(version) < version_timestamp(current_version)}
      old_versions.each do |version|
        ElasticSearchable.searcher.delete_index(version)
      end
    end

    # lists all current, old, an in-progress versions for this index
    def index_versions(index)
      ElasticSearchable.searcher.index_status()["indices"].keys.grep(/^#{index}_/)
    end
    
    private
      def version_timestamp(version)
        version.gsub(/^.*_/, "").to_i
      end
    
  end
  
  module HitExtensions
    def to_activerecord
      model_class = _type.gsub(/-/,'/').classify.constantize
      begin
        model_class.find(_id) 
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end