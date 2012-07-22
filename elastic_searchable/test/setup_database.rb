config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite'])

ActiveRecord::Schema.define(:version => 1) do
  create_table :posts, :force => true do |t|
    t.column :title, :string
    t.column :body, :string
    t.column :name, :string
  end
  create_table :blogs, :force => true do |t|
    t.column :title, :string
    t.column :body, :string
  end
  create_table :users, :force => true do |t|
    t.column :name, :string
  end
  create_table :friends, :force => true do |t|
    t.column :name, :string
    t.column :favorite_color, :string
    t.belongs_to :book
  end
  create_table :books, :force => true do |t|
    t.column :title, :string
    t.column :isbn, :string
  end
  create_table :max_page_size_classes, :force => true do |t|
    t.column :name, :string
  end
  create_table :parents, :force => true do |t|
    t.column :name, :string
    t.column :description, :string
  end
  create_table :children, :force => true do |t|
    t.column :name, :string
    t.column :description, :string
    t.belongs_to :parent
  end
end
