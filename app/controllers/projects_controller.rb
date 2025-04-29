class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.xml

  layout :determine_layout

  def index
    @projects = LinkedData::Client::Models::Project.all || []
    @projects.reject! { |p| p.name.nil? }
    
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true) || []
    @ontologies_hash = Hash[@ontologies.map {|ont| [ont.id, ont]}]
    
    setup_funder_options
    setup_categories_options
    
    @projects = filter_projects(@projects) if params[:search].present?
    @projects = filter_by_status(@projects) if params[:funded_only].present? || params[:active_only].present?
    @projects = filter_by_funder(@projects) if params[:funder].present? && params[:funder] != ''
    @projects = filter_by_categories(@projects) if params[:categories].present?
    
    @search = params[:search] || ""
    @sort_by = params[:sort_by] || "name"
    @sorts_options = [
      [t('projects.sort.name'), 'name'],
      [t('projects.sort.acronym'), 'acronym'], 
      [t('projects.sort.start_date'), 'start_date'],
      [t('projects.sort.end_date'), 'end_date'],
      [t('projects.sort.ontologies'), 'ontologies']
    ]
    
    @projects = sort_projects_by(@projects, @sort_by)
  end

  def projects_filter
    all_projects = LinkedData::Client::Models::Project.all || []
    all_projects.reject! { |p| p.name.nil? }
    
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true) || []
    @ontologies_hash = Hash[@ontologies.map {|ont| [ont.id, ont]}]
    
    setup_funder_options_from_projects(all_projects)
    setup_categories_options_from_projects(all_projects)
    
    @projects = all_projects
    
    @projects = filter_projects(@projects) if params[:search].present?
    @projects = filter_by_status(@projects) if params[:funded_only].present? || params[:active_only].present?
    @projects = filter_by_funder(@projects) if params[:funder].present? && params[:funder] != ''
    @projects = filter_by_categories(@projects) if params[:categories].present?
    
    sort_param = params[:sort_by] || 'name'
    @projects = sort_projects_by(@projects, sort_param)
    
    render partial: 'projects_list', locals: { projects: @projects }
  end

  # GET /projects/1
  # GET /projects/1.xml
  def show
    projects = LinkedData::Client::Models::Project.find_by_acronym(params[:id])
    if projects.nil? || projects.empty?
      flash[:notice] = flash_error(t('projects.project_not_found', id: params[:id]))
      redirect_to projects_path
      return
    end

    @project = projects.first

    @dates_properties = {}
    @dates_properties[:start_date] = @project.start_date if @project.start_date.present?
    @dates_properties[:end_date] = @project.end_date if @project.end_date.present?
    @dates_properties.compact!

    @ontologies_used = []
    onts_used = @project.ontologyUsed
    onts_used.each do |ont_used|
      ont = LinkedData::Client::Models::Ontology.find(ont_used)
      unless ont.nil? || ont.errors
        @ontologies_used << Hash["name", ont.name, "acronym", ont.acronym]
      end
    end
    @ontologies_used.sort_by!{ |o| o["name"].downcase }
  end

  # GET /projects/new
  # GET /projects/new.xml
  def new
    @step = params[:step].present? ? params[:step].to_i : 1
    if session[:user].nil?
      redirect_to :controller => 'login', :action => 'index'
    else
      @project = LinkedData::Client::Models::Project.new
      @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
      @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    end
  end

  # GET /projects/1/edit
  def edit
    projects = LinkedData::Client::Models::Project.find_by_acronym(params[:id])
    if projects.nil? || projects.empty?
      flash[:notice] = flash_error(t('projects.project_not_found', id: params[:id]))
      redirect_to projects_path
      return
    end
    @project = projects.first
    @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
    @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    @usedOntologies = @project.ontologyUsed&.map{|o| o.split('/').last}
    @ontologies = LinkedData::Client::Models::Ontology.all
  end

  # POST /projects
  # POST /projects.xml
  def create
    if params['commit'] == 'Cancel'
      redirect_to projects_path
      return
    end
    create_params = project_params.to_h
    
    create_params[:creator] = [session[:user].id]
    
    create_params[:type] ||= "FundedProject"
    
    organization_id = nil
    if params[:project][:organizations_attributes].present?
      orgs = params[:project][:organizations_attributes].values
      organization_id = orgs.first["id"] if orgs.first && orgs.first["id"].present?
      create_params[:organization] = organization_id
    end
  
    contact_id = nil
    if params[:project][:contacts_attributes].present?
      contacts = params[:project][:contacts_attributes].values
      contact_id = contacts.first["id"] if contacts.first && contacts.first["id"].present?
      create_params[:contact] = contact_id
    end

    create_params[:funder] = params[:project][:funders_attributes]&.values&.first&.dig("id")
  
    create_params[:ontologyUsed] ||= []
  
    @project = LinkedData::Client::Models::Project.new(values: create_params)
    @project_saved = @project.save

    # Project successfully created.
    if response_success?(@project_saved)
      flash[:notice] = t('projects.project_successfully_created')
      redirect_to project_path(@project.acronym)
      return
    end
  
    # Errors creating project.
    if @project_saved.status == 409
      error = OpenStruct.new existence: t('projects.error_unique_acronym', acronym: params[:project][:acronym])
      @errors = Hash[:error, OpenStruct.new(acronym: error)]
    else
      @errors = response_errors(@project_saved)
    end
    @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
    @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    render action: "new"
  end

  # PUT /projects/1
  # PUT /projects/1.xml
  def update
    if params['commit'] == 'Cancel'
      redirect_to projects_path
      return
    end
    projects = LinkedData::Client::Models::Project.find_by_acronym(params[:id])
    if projects.nil? || projects.empty?
      flash[:notice] = flash_error(t('projects.project_not_found', id: params[:id]))
      redirect_to projects_path
      return
    end
    @project = projects.first
    @project.update_from_params(project_params)
    @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
    @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    @usedOntologies = @project.ontologyUsed || []
    @ontologies = LinkedData::Client::Models::Ontology.all
    error_response = @project.update
    if response_error?(error_response)
      @errors = response_errors(error_response)
      render :edit
    else
      flash[:notice] = t('projects.project_successfully_updated')
      redirect_to project_path(@project.acronym)
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.xml
  def destroy
    projects = LinkedData::Client::Models::Project.find_by_acronym(params[:id])
    if projects.nil? || projects.empty?
      flash[:notice] = flash_error(t('projects.project_not_found', id: params[:id]))
      redirect_to projects_path
      return
    end
    @project = projects.first
    error_response = @project.delete
    if response_error?(error_response)
      @errors = response_errors(error_response)
      flash[:notice] = t('projects.error_delete_project', errors: @errors)
      respond_to do |format|
        format.html { redirect_to projects_path }
        format.xml  { head :internal_server_error }
      end
    else
      flash[:notice] = t('projects.project_successfully_deleted')
      respond_to do |format|
        format.html { redirect_to projects_path }
        format.xml  { head :ok }
      end
    end

  end


  def search_external_projects
    source = params[:source]
    search_term = params[:term]
    search_type = params[:type] || "acronym"
    
    if source.blank? || search_term.blank?
      render json: { success: false, results: [], message: "Missing required parameters" }
      return
    end
    
    begin
      endpoint = "/connector/projects"
      
      response = api_connection.get(endpoint) do |req|
        req.params[search_type.to_sym] = search_term
        req.params[:source] = source
      end
      
      case response.status
      when 200
        if response.body && response.body.is_a?(Hash) && response.body.key?("collection")
          results = response.body["collection"] || []

          results.each do |project|
            if project["funder"] && project["funder"]["value"]
              funder_uri = project["funder"]["value"]
              agent_id = funder_uri.split('/').last
              response = api_connection.get("/agents/#{agent_id}")
              project["funder"] = response.body if response.status == 200 && response.body
            end
          end


          render json: {
            success: true,
            results: results,
            message: results.any? ? "Found #{results.length} projects" : "No projects found"
          }
        else
          render json: { success: false, results: [], message: "Invalid response format from API" }
        end
      when 404
        render json: { success: false, results: [], message: "No projects found matching search criteria" }
      else
        handle_error_response(response)
      end
      
    rescue Faraday::ConnectionFailed
      render json: { success: false, results: [], message: "Connection to API failed" }
    rescue => e
      render json: { success: false, results: [], message: "An error occurred", error: e.message }
    end
  end


  private

    def setup_categories_options
    setup_categories_options_from_projects(@projects)
  end

  def setup_categories_options_from_projects(projects)
    unless @ontologies_hash
      @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true) || []
      @ontologies_hash = Hash[@ontologies.map {|ont| [ont.id, ont]}]
    end
    
    categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    all_projects = LinkedData::Client::Models::Project.all || []
    all_projects.reject! { |p| p.name.nil? }
    
    category_counts = count_projects_by_categories(all_projects)
    
    category_objects = categories.map do |category|
      {
        'id' => category.id,
        'name' => category.name,
        'acronym' => category.acronym || category.name,
        'value' => category.acronym || category.name,
        'displayName' => category.name
      }
    end
    
    selected_categories = Array(params[:categories])
    count = selected_categories.length
    
    @categories_filters = [category_objects, selected_categories, count]
    @count_objects ||= {}
    @count_objects[:categories] = category_counts
  end

  def filter_by_categories(projects)
    return projects unless params[:categories].present?
    
    selected_categories = if params[:categories].is_a?(String)
                            params[:categories].split(',').map(&:strip)
                          else
                            Array(params[:categories])
                          end
    
    categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    category_mapping = categories.map { |cat| [cat.acronym || cat.name, cat.id] }.to_h
    selected_category_ids = selected_categories.map { |acronym| category_mapping[acronym] }.compact
    
    projects.select do |project|
      project_ontologies = Array(project.ontologyUsed)
      
      project_ontologies.any? do |ontology_id|
        ontology = @ontologies_hash[ontology_id]
        next false unless ontology
        
        ontology_categories = Array(ontology.hasDomain)
        selected_category_ids.any? { |selected_cat| ontology_categories.include?(selected_cat) }
      end
    end
  end

  def count_categories
    category_acronym = params[:acronym]
    all_projects = LinkedData::Client::Models::Project.all || []
    all_projects.reject! { |p| p.name.nil? }
    
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true) || []
    @ontologies_hash = Hash[@ontologies.map {|ont| [ont.id, ont]}]
    
    category_counts = count_projects_by_categories(all_projects)
    categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    category = categories.find { |cat| (cat.acronym || cat.name) == category_acronym }
    
    count = category ? (category_counts[category.id] || 0) : 0
    render plain: count.to_s
  end

  def count_projects_by_categories(projects)
    category_counts = {}
    
    unless @ontologies_hash
      ontologies = LinkedData::Client::Models::Ontology.all(include_views: true) || []
      @ontologies_hash = Hash[ontologies.map {|ont| [ont.id, ont]}]
    end
    
    projects.each do |project|
      project_ontologies = Array(project.ontologyUsed)
      project_categories = Set.new
      
      project_ontologies.each do |ontology_id|
        ontology = @ontologies_hash[ontology_id]
        next unless ontology
        
        ontology_categories = Array(ontology.hasDomain)
        ontology_categories.each { |category_id| project_categories.add(category_id) }
      end
      
      project_categories.each do |category_id|
        category_counts[category_id] ||= 0
        category_counts[category_id] += 1
      end
    end
    
    category_counts
  end

  def setup_funder_options
    setup_funder_options_from_projects(@projects)
  end

  def setup_funder_options_from_projects(projects)
    unique_funders = projects.map(&:funder).compact.uniq.sort_by(&:name).uniq(&:name)
    @funder_options = [[t('projects.filter.not_funded'), 'not_funded']]
    
    unique_funders.each do |funder|
      acronym = funder.acronym.present? ? funder.acronym : funder.name
      value = funder.name.downcase.gsub(/\s+/, '_')
      @funder_options << [acronym, value]
    end
  end

  def filter_by_funder(projects)
    return projects unless params[:funder].present?
    
    selected_funder = params[:funder]
    
    projects.select do |project|
      case selected_funder
      when 'not_funded'
        project.funder.nil? || project.funder.name.blank?
      when ''
        true
      else
        project.funder && project.funder.name.downcase.gsub(/\s+/, '_') == selected_funder
      end
    end
  end

  def sort_projects_by(projects, sort_by)
    case sort_by
    when 'name'
      projects.sort_by { |p| (p.name || "").downcase }
    when 'acronym'
      projects.sort_by { |p| (p.acronym || "").downcase }
    when 'start_date'
      projects.sort_by do |p|
        if p.start_date.present?
          Date.parse(p.start_date.to_s) rescue Date.new(1900, 1, 1)
        else
          Date.new(1900, 1, 1)
        end
      end.reverse
    when 'end_date'
      projects.sort_by do |p|
        if p.end_date.present?
          Date.parse(p.end_date.to_s) rescue Date.new(1900, 1, 1)
        else
          Date.new(2100, 1, 1)
        end
      end.reverse
    when 'ontologies'
      projects.sort_by { |p| -(p.ontologyUsed&.length || 0) }
    else
      projects.sort_by { |p| (p.name || "").downcase }
    end
  end

  def filter_projects(projects)
    return projects unless params[:search].present?
    
    query = params[:search].downcase
    projects.select do |project|
      project.name&.downcase&.include?(query) ||
      project.description&.downcase&.include?(query) ||
      project.acronym&.downcase&.include?(query) ||
      project.organization&.name&.downcase&.include?(query) ||
      project.organization&.acronym&.downcase&.include?(query)
    end
  end

  def filter_by_status(projects)
    projects = projects.select { |p| p.type == "FundedProject" } if params[:funded_only] == "true"
    projects = projects.select { |p| project_active?(p) } if params[:active_only] == "true"
    projects
  end

  def project_active?(project)
    return true unless project.end_date.present?
    Date.parse(project.end_date) >= Date.current rescue true
  end

  def project_params
    params.require(:project).permit(
      :acronym, { creator: [] }, :type, :name, :homePage, :description, 
      { ontologyUsed: [] }, :source, :keywords, :contact, :organization, 
      :logo, :grant_number, :start_date, :end_date, :funder,
      organizations_attributes: [:id], contacts_attributes: [:id], funders_attributes: [:id]
    )
  end

  def flash_error(msg)
    html = ''.html_safe
    html << '<span style=color:red;>'.html_safe
    html << msg
    html << '</span>'.html_safe
  end

  def api_connection
    apikey = session[:user].try(:apikey)
    
    @api_connection ||= Faraday.new(ENV['API_URL']) do |faraday|
      faraday.params['apikey'] = apikey
      faraday.request :url_encoded
      faraday.response :json, content_type: /\bjson$/
      faraday.options[:timeout] = 30
      faraday.options[:open_timeout] = 10
      faraday.adapter Faraday.default_adapter
    end
  end

  def handle_error_response(response)
    message = case response.status
              when 400...500
                "Invalid request: #{response.body['error'] || 'Bad request'}"
              when 500...600
                "Server error: The external service is currently unavailable"
              else
                "Unexpected response: #{response.status}"
              end
    
    respond_to do |format|
      format.json { render json: { success: false, results: [], message: message } }
      format.html { render json: { success: false, results: [], message: message } }
    end
  end

end
