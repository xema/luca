module Luca
  module Rails
    class Engine < ::Rails::Engine
      initializer "luca.register_template" do |app|
        app.assets.register_engine ".luca", Luca::Template
        Luca::TestHarness.set(:sprockets,app.assets)
        Luca::TestHarness.set :root, File.expand_path('../../../../', __FILE__)
      end
    end
  end
end

