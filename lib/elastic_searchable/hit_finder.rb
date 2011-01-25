module ElasticSearchable
  module HitFinder
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
