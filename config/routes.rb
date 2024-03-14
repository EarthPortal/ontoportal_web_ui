Rails.application.routes.draw do

  root to: 'home#index'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get 'auth/:provider/callback', to: 'login#create_omniauth'
  get 'locale/:language', to: 'language#set_locale_language'
  get 'metadata_export/index'

  get '/notes/new_comment', to: 'notes#new_comment'
  get '/notes/new_proposal', to: 'notes#new_proposal'
  get '/notes/new_reply', to: 'notes#new_reply'
  delete '/notes', to: 'notes#destroy'
  resources :notes, constraints: { id: /.+/ }
  get 'agents/show_search', to: 'agents#show_search'
  get 'agents/:id/usages', to: 'agents#agent_usages', constraints: { id: /.+/ }
  post 'agents/:id/usages', to: 'agents#update_agent_usages', constraints: { id: /.+/ }
  resources :agents, constraints: { id: /.+/ }
  post 'agents/:id', to: 'agents#update', constraints: { id: /.+/ }
  resources :ontolobridge do
    post :save_new_term_instructions, on: :collection
  end

  resources :projects, constraints: { id: /[^\/]+/ }

  resources :users, path: :accounts, constraints: { id: /[\d\w\.\-\%\+ ]+/ }

  get '/users/subscribe/:username', to: 'users#subscribe'
  get '/users/un-subscribe/:email', to: 'users#un_subscribe'

  get '/mappings/loader', to: 'mappings#loader'
  post '/mappings/loader', to: 'mappings#loader_process'
  get 'mappings/count/:id', to: 'mappings#count', constraints: { id: /.+/ }
  get 'mappings/ontology_mappings/:acronym', to: 'mappings#ontology_mappings'
  get 'mappings/show_mappings', to: 'mappings#show_mappings'
  get 'mappings/new', to: 'mappings#new'
  get 'mappings/:id', to: 'mappings#show', constraints: { id: /.+/ }
  post 'mappings/:id', to: 'mappings#update', constraints: { id: /.+/ }
  delete 'mappings/:id', to: 'mappings#destroy', constraints: { id: /.+/ }
  resources :mappings
  get 'mappings/:id', to: 'mappings#show', constraints: { id: /.+/ }
  get '/mappings_table', to: 'mappings#show_table'

  resources :concepts

  get 'ontologies/:ontology_id/concepts', to: 'concepts#show_concept'
  resources :ontologies do
    resources :submissions do
      get 'edit_properties'
    end

    get 'instances/:instance_id', to: 'instances#show', constraints: { instance_id: /[^\/?]+/ }
    get 'schemes/show_scheme', to: 'schemes#show'
    get 'collections/show'
    get 'metrics'
    get 'metrics_evolution'
    get 'subscriptions'
  end

  resources :login

  resources :admin, only: [:index]

  namespace :admin do
    resources :licenses, only: [:index, :create, :new]
    match 'groups/synchronize_groups' => 'groups#synchronize_groups', via: [:post]
    resources :groups, only: [:index, :create, :new, :edit, :update, :destroy]
    resources :categories, only: [:index, :create, :new, :edit, :update, :destroy]
  end

  post 'admin/clearcache', to: 'admin#clearcache'
  post 'admin/resetcache', to: 'admin#resetcache'
  post 'admin/clear_goo_cache', to: 'admin#clear_goo_cache'
  post 'admin/clear_http_cache', to: 'admin#clear_http_cache'
  get 'admin/ontologies_report', to: 'admin#ontologies_report'
  post 'admin/refresh_ontologies_report', to: 'admin#refresh_ontologies_report'
  delete 'admin/ontologies', to: 'admin#delete_ontologies'
  put 'admin/ontologies', to: 'admin#process_ontologies'
  get 'admin/update_check_enabled', to: 'admin#update_check_enabled'
  get 'admin/ontologies/:acronym/log', to: 'admin#parse_log'

  resources :subscriptions

  resources :recommender

  get '/annotator', to: 'annotator#index'
  get '/annotatorplus', to: 'annotator#annotator_plus'
  get '/ncbo_annotatorplus', to: 'annotator#ncbo_annotator_plus'


  resources :virtual_appliance

  get 'change_requests/create_synonym'
  match 'change_requests', to: 'change_requests#create', via: :post

  # resource for metadata ontologies
  scope :ontologies_metadata_curator do
    post '/result', to: 'ontologies_metadata_curator#result'
    post '/edit', to: 'ontologies_metadata_curator#edit'
    put '/update', to: 'ontologies_metadata_curator#update'
    get '/:ontology/submissions/:submission_id/attributes/:attribute', to: 'ontologies_metadata_curator#show_metadata_value'
    get '/:ontology/submissions/:submission_id', to: 'ontologies_metadata_curator#show_metadata_by_ontology'
  end

  get '' => 'home#index'

  match 'sparql_proxy', to: 'admin#sparql_endpoint', via: [:get, :post]

  # Top-level pages
  match '/feedback', to: 'home#feedback', via: [:get, :post]
  get '/account' => 'home#account'
  get '/site_config' => 'home#site_config'
  post '/annotator_recommender_form' => 'home#annotator_recommender_form'
  match '/visits', to: 'visits#index', via: :get
  get 'statistics/index'

  # Error pages
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  # Robots.txt
  get '/robots.txt' => 'robots#index'

  # Ontologies
  get '/ontologies/view/edit/:id' => 'ontologies#edit_view', :constraints => { id: /[^\/?]+/ }
  get '/ontologies/view/new/:id' => 'ontologies#new_view'

  get '/ontologies/virtual/:ontology' => 'ontologies#virtual', :as => :ontology_virtual
  get '/ontologies/success/:id' => 'ontologies#submit_success'
  match '/ontologies/:acronym' => 'ontologies#update', via: [:get, :post]
  match '/ontologies/:acronym/submissions/:id' => 'submissions#update', via: [:get, :post]
  get '/ontologies/:ontology_id/submissions/new' => 'submissions#new', :ontology_id => /.+/
  match '/ontologies/:ontology_id/submissions' => 'submissions#create', :ontology_id => /.+/, via: [:post]
  match '/ontologies/:ontology_id/submissions' => 'submissions#index', :ontology_id => /.+/, via: [:get]
  get '/ontologies/:acronym/classes/:purl_conceptid', to: 'ontologies#show', constraints: { purl_conceptid: /[^\/]+/ }
  get '/ontologies/:acronym/: f', to: 'ontologies#show', constraints: { purl_conceptid: /[^\/]+/ }
  match '/ontologies/:acronym/submissions/:id/edit_metadata' => 'submissions#edit_metadata', via: [:get, :post]
  get '/ontologies_filter', to: 'ontologies#ontologies_filter'

  get '/ontologies/:acronym/properties/show', to: 'properties#show'
  get 'ontologies_selector', to: 'ontologies#ontologies_selector'
  get 'ontologies_selector/results', to: 'ontologies#ontologies_selector_results'
  # Notes
  get 'ontologies/:ontology/notes/:noteid', to: 'notes#virtual_show', as: :note_virtual, noteid: /.+/
  get 'ontologies/:ontology/notes', to: 'notes#virtual_show'

  # Ajax
  get '/ajax/' => 'ajax_proxy#get', :as => :ajax
  get '/ajax_concepts/:ontology/' => 'concepts#show', :constraints => { id: /[^\/?]+/ }
  get '/ajax/class_details' => 'concepts#details'
  get '/ajax/mappings/get_concept_table' => 'mappings#get_concept_table'
  get '/ajax/json_ontology' => 'ajax_proxy#json_ontology'
  get '/ajax/json_class' => 'ajax_proxy#json_class'
  get '/ajax/jsonp' => 'ajax_proxy#jsonp'
  get '/ajax/notes/delete' => 'notes#destroy'
  get '/ajax/notes/concept_list' => 'notes#show_concept_list'
  get '/ajax/classes/label' => 'concepts#show_label'
  get '/ajax/classes/definition' => 'concepts#show_definition'
  get '/ajax/classes/treeview' => 'concepts#show_tree'
  get '/ajax/classes/list' => 'collections#show_members'
  get '/ajax/classes/date_sorted_list' => 'concepts#show_date_sorted_list'
  get '/ajax/properties/treeview' => 'properties#show_tree'
  get '/ajax/properties/children' => 'properties#show_children'
  get '/ajax/properties/tree' => 'concepts#property_tree'
  get 'ajax/schemes/label', to: "schemes#show_label"
  get 'ajax/collections/label', to: "collections#show_label"
  get 'ajax/label_xl/label', to: "label_xl#show_label"
  get 'ajax/label_xl', to: "label_xl#show"
  get '/ajax/biomixer' => 'concepts#biomixer'
  get '/ajax/fair_score/html' => 'fair_score#details_html'
  get '/ajax/submission/show_licenses/:id' => 'ontologies#show_licenses'
  get '/ajax/fair_score/json' => 'fair_score#details_json'
  get '/ajax/:ontology/instances' => 'instances#index_by_ontology'
  get '/ajax/:ontology/classes/:conceptid/instances' => 'instances#index_by_class', :constraints => { conceptid: /[^\/?]+/ }
  get '/ajax/ontologies', to: "ontologies#ajax_ontologies"
  get '/ajax/agents', to: "agents#ajax_agents"
  get '/ajax/images/show' => 'application#show_image_modal'
  # User
  get '/logout' => 'login#destroy', :as => :logout
  get '/lost_pass' => 'login#lost_password'
  get '/lost_pass_success' => 'login#lost_password_success'
  get '/reset_password' => 'login#reset_password'
  post '/accounts/:id/custom_ontologies' => 'users#custom_ontologies', :as => :custom_ontologies
  get '/login_as/:login_as' => 'login#login_as', constraints: { login_as: /[\d\w\.\-\%\+ ]+/ }
  post '/login/send_pass', to: 'login#send_pass'

  # Search
  get 'search', to: 'search#index'

  get 'check_resolvability' => 'check_resolvability#index'
  get 'check_url_resolvability' => 'check_resolvability#check_resolvability'

  ###########################################################################################################
  # Install the default route as the lowest priority.
  get '/:controller(/:action(/:id))'
  ###########################################################################################################

  #####
  ## OLD ROUTES
  ## All of these should redirect to new addresses in the controller method or using the redirect controller
  #####

  # Redirects from old URL locations
  get '/annotate' => 'redirect#index', :url => '/annotator'
  get '/visconcepts/:ontology/' => 'redirect#index', :url => '/visualize/'
  get '/ajax/terms/label' => 'redirect#index', :url => '/ajax/classes/label'
  get '/ajax/terms/definition' => 'redirect#index', :url => '/ajax/classes/definition'
  get '/ajax/terms/treeview' => 'redirect#index', :url => '/ajax/classes/treeview'
  get '/ajax/term_details/:ontology' => 'redirect#index', :url => '/ajax/class_details'
  get '/ajax/json_term' => 'redirect#index', :url => '/ajax/json_class'

  # Visualize
  get '/visualize/:ontology' => 'ontologies#visualize', :as => :visualize, :constraints => { ontology: /[^\/?]+/ }
  get '/visualize/:ontology/:conceptid' => 'ontologies#visualize', :as => :uri, :constraints => { ontology: /[^\/?]+/, conceptid: /[^\/?]+/ }
  get '/visualize' => 'ontologies#visualize', :as => :visualize_concept, :constraints => { ontology: /[^\/?]+/, id: /[^\/?]+/, ontologyid: /[^\/?]+/, conceptid: /[^\/?]+/ }

  get '/exhibit/:ontology/:id' => 'concepts#exhibit'

  mount Lookbook::Engine, at: "/lookbook"

end
