class Book < ActiveRecord::Base
  elastic_searchable
  after_percolate :on_percolated
  def on_percolated
    @percolated = percolations
  end
  def percolated
    @percolated
  end
end
