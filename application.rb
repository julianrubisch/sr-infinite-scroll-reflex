require "action_controller/railtie"
require "action_cable/engine"
require "active_model"
require "active_record"
require "nulldb/rails"
require "rails/command"
require "rails/commands/server/server_command"
require "cable_ready"
require "stimulus_reflex"
require "pagy"
require "pagy/extras/array"

ITEMS = (1..30).to_a.freeze

module ApplicationCable; end

class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :session_id

  def connect
    self.session_id = request.session.id
  end  
end

class ApplicationCable::Channel < ActionCable::Channel::Base; end

class ApplicationController < ActionController::Base; end

class ApplicationReflex < StimulusReflex::Reflex; end

class InfiniteScrollReflex < ApplicationReflex
  include Pagy::Backend

  attr_reader :collection

  def load_more
    cable_ready.insert_adjacent_html(
      selector: selector,
      html: render(inline: "<% collection.each do |item| %><div class=\"mb-3 row border border-3 p-3 mx-0\">
<%= item %></div><% end %>", locals: {collection: collection}),
      position: position
    )
  end

  def page
    element.dataset.next_page
  end
  
  def position
    "beforebegin"
  end

  def selector
    raise NotImplementedError
  end
end

class ItemsInfiniteScrollReflex < InfiniteScrollReflex
  def load_more
    @pagy, @collection = pagy_array ITEMS, items: 5, page: page
    
    super
  end

  def selector
    "#sentinel"
  end
end

class DemosController < ApplicationController
  include Pagy::Backend  
  
  def show
    @pagy, @collection = pagy_array ITEMS, items: 5 unless @stimulus_reflex

    render inline: <<~HTML
      <html>
        <head>
          <title>InfiniteScrollReflex Pattern</title>
          <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet">
          <%= javascript_include_tag "/index.js", type: "module" %>
        </head>
        <body>
          <div class="container my-5">
            <h1>InfiniteScrollReflex</h1>
            
            <% @collection.each do |item| %>
              <div class="mb-3 row border border-3 p-3 mx-0">
                <%= item %>
              </div>
            <% end %>
            
            <div id="sentinel" class="d-none"></div>
            
            <div id="load-more" class="d-grid gap-2">
              <% if @pagy.page < @pagy.last %>              
                <button class="btn btn-primary" 
                  type="button"
                  data-reflex="click->ItemsInfiniteScroll#load_more"
                  data-next-page="<%= @pagy.page + 1 %>"              
                  data-reflex-root="#load-more">
                  Load more
                </button>              
              <% end %>
            </div>
          </div>        
        </body>
      </html>
    HTML
  end
end

class MiniApp < Rails::Application
  require "stimulus_reflex/../../app/channels/stimulus_reflex/channel"

  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "cde22ece34fdd96d8c72ab3e5c17ac86"
  config.secret_token = "bf56dfbbe596131bfca591d1d9ed2021"
  config.session_store :cache_store
  config.hosts.clear

  Rails.cache = ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6379/1")
  Rails.logger = ActionCable.server.config.logger = Logger.new($stdout)
  ActionCable.server.config.cable = {"adapter" => "redis", "url" => "redis://localhost:6379/1"}
  StimulusReflex.config.logger = Rails.logger
  Pagy::DEFAULT.freeze  
  
  routes.draw do
    mount ActionCable.server => "/cable"
    get '___glitch_loading_status___', to: redirect('/')
    resource :demo, only: :show
    root "demos#show"
  end
end

ActiveRecord::Base.establish_connection adapter: :nulldb, schema: "schema.rb"

Rails::Server.new(app: MiniApp, Host: "0.0.0.0", Port: ARGV[0]).start
