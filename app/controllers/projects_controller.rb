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
    onts_used = @project.ontologyUsed || []
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
      redirect_to controller: 'login', action: 'index'
    else
      @project = LinkedData::Client::Models::Project.new
      @user_select_list = load_user_select_list
    end
  end

  def edit
    if session[:user].nil?
      redirect_to controller: 'login', action: 'index'
      return
    end

    @project = find_project_or_redirect
    return unless @project

    user_id = session[:user].id
    is_admin = session[:user].admin?
    is_creator = Array(@project.creator).include?(user_id)

    unless is_creator || is_admin
      flash[:alert] = t('projects.edit.not_authorized')
      redirect_to project_path(@project.acronym)
      return
    end

    @user_select_list = load_user_select_list
    @usedOntologies = @project.ontologyUsed&.map { |o| o.split('/').last }
    @ontologies = LinkedData::Client::Models::Ontology.all
  end

  def create
    if params['commit'] == 'Cancel'
      redirect_to projects_path 
      return
    end
    
    create_params = project_params.to_h
    create_params[:creator] = [session[:user].id]
    
    project_type = params[:project][:project_type].presence || 'funded'
    set_project_type(create_params, project_type)
    
    org_id = extract_organization_id
    if org_id.present?
      create_params[:organization] = org_id
      @organization = fetch_agent(org_id)
    end
    
    contact_ids = extract_contact_ids
    create_params[:contact] = contact_ids if contact_ids.any?
    
    create_params[:ontologyUsed] ||= []
    
    @project = LinkedData::Client::Models::Project.new(values: create_params)
    @project_saved = @project.save
    
    # Handle response
    handle_create_response
  end

  def update
    if params['commit'] == 'Cancel'
      redirect_to projects_path 
      return
    end

    @project = find_project_or_redirect
    return unless @project
    
    @project.update_from_params(project_params)
    
    org_id = extract_organization_id
    if org_id.present?
      @project.organization = org_id
      @organization = fetch_agent(org_id)
    end
    
    contact_ids = extract_contact_ids
    @project.contact = contact_ids if contact_ids.any?
    
    @project.start_date = nil if @project.start_date.blank?
    @project.end_date = nil if @project.end_date.blank?
    @project.funder = extract_id(@project.funder)
    @project.type = "FundedProject" unless %w[FundedProject NonFundedProject].include?(@project.type)
    @project.creator ||= [session[:user].id] if session[:user]
    
    setup_data_for_edit
    
    begin
      minimal_update = {
        id: @project.id,
        acronym: @project.acronym,
        name: @project.name,
        description: @project.description,
        type: @project.type,
      }
      
      if @project.organization.present?
        org_id = extract_organization_from_object(@project.organization)
        minimal_update[:organization] = org_id if org_id.present?
      end
      
      update_project = LinkedData::Client::Models::Project.new(values: minimal_update)
      error_response = update_project.update
      
      if response_error?(error_response)
        @errors = response_errors(error_response)
        render :edit
      else
        full_update = {
          id: @project.id,
          organization: org_id,
          homePage: @project.homePage,
          keywords: @project.keywords,
          logo: @project.logo,
          grant_number: @project.grant_number,
          start_date: @project.start_date,
          end_date: @project.end_date,
          ontologyUsed: @project.ontologyUsed,
          source: @project.source,
          contact: @project.contact

        }
        
        full_project = LinkedData::Client::Models::Project.new(values: full_update)
        full_project.update rescue nil  # Ignore errors on secondary update
        
        flash[:notice] = t('projects.project_successfully_updated')
        redirect_to project_path(@project.acronym)
      end
    rescue => e
      @errors = { error: { general: OpenStruct.new(existence: "Error updating project: #{e.message}") } }
      render :edit
    end
  end

  def destroy
    @project = find_project_or_redirect
    return unless @project

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

  def ajax_projects
    query = params[:query].to_s.strip.downcase
    limit = params[:limit]&.to_i || 20

    projects = LinkedData::Client::Models::Project.all || []

    if query.present?
      projects = projects.select do |project|
        project.name&.downcase&.include?(query) ||
        project.acronym&.downcase&.include?(query) ||
        project.description&.downcase&.include?(query)
      end
    end

    projects = projects.first(limit)

    projects_json = projects.map do |project|
      {
        value: project.acronym, 
        text: "#{project.name} (#{project.acronym})"
      }
    end
    render json: projects_json
  end
  
  def search_external_projects
    source = params[:source]
    search_term = params[:term]
    search_type = params[:type] || "acronym"
    
    if source.blank? || search_term.blank?
      render json: { 
        success: false, 
        results: [], 
        message: t('projects.search.missing_parameters') 
      }
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
              agent_response = api_connection.get("/agents/#{agent_id}")
              project["funder"] = agent_response.body if agent_response.status == 200 && agent_response.body
            end
          end

          render json: {
            success: true,
            results: results,
            message: results.any? ? 
              t('projects.search.found_projects', count: results.length) : 
              t('projects.search.no_projects_found')
          }
        else
          render json: { 
            success: false, 
            results: [], 
            message: t('projects.search.invalid_response_format') 
          }
        end
      when 404
        render json: { 
          success: false, 
          results: [], 
          message: t('projects.search.no_projects_found_criteria') 
        }
      else
        handle_error_response(response)
      end
      
    rescue Faraday::ConnectionFailed
      render json: { 
        success: false, 
        results: [], 
        message: t('projects.search.connection_failed') 
      }
    rescue => e
      render json: { 
        success: false, 
        results: [], 
        message: t('projects.search.error_occurred'), 
        error: e.message 
      }
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
      project.acronym&.downcase&.include?(query) ||
      project.organization&.name&.downcase&.include?(query) ||
      project.organization&.acronym&.downcase&.include?(query)
    end
  end

  def filter_by_status(projects)
    if params[:funded_only] == "true"
      projects = projects.select { |p| p.funder.present? }
    end
    projects = projects.select { |p| project_active?(p) } if params[:active_only] == "true"
    projects
  end

  def project_active?(project)
    return true unless project.end_date.present?
    Date.parse(project.end_date) >= Date.current rescue true
  end

  
  def extract_id(val)
    return val.id if val.respond_to?(:id)
    return val['id'] if val.is_a?(Hash)
    val
  end

  def extract_agent_id(params_hash)
    return nil unless params_hash.present?
    
    if params_hash.is_a?(Hash)
      # Handle nested structure: {"id123" => {"id" => "full/uri/path"}}
      params_hash.values.first&.dig("id") if params_hash.values.first.is_a?(Hash)
    else
      # Handle direct ID
      params_hash
    end
  end

  def extract_organization_id
    # Try organization (direct format)
    org_id = extract_agent_id(params[:project][:organization])
    return org_id if org_id.present?
    
    # Try organizations_attributes (nested attributes format)
    if params[:project][:organizations_attributes].present?
      orgs = params[:project][:organizations_attributes].values
      orgs.first&.dig("id")
    end
  end

  def extract_organization_from_object(organization_object)
    if organization_object.is_a?(ActionController::Parameters)
      organization_object.each do |key, value|
        if value.is_a?(ActionController::Parameters) && value["id"].present?
          return value["id"]
        end
      end
    end
    
    organization_object
  end

  def extract_contact_ids
    # Try direct contact array
    return Array(params[:project][:contact]) if params[:project][:contact].present?
    
    # Try contacts_attributes (nested format)
    if params[:project][:contacts_attributes].present?
      contacts = params[:project][:contacts_attributes].values
      contacts.map { |c| c["id"] if c["id"].present? }.compact
    else
      []
    end
  end

  def fetch_agent(id)
    return nil unless id.present?
    agent_acronym = id.split('/').last rescue id
    LinkedData::Client::Models::Agent.find(agent_acronym).first rescue nil
  end


  def find_project_or_redirect
    projects = LinkedData::Client::Models::Project.find_by_acronym(params[:id])
    if projects.nil? || projects.empty?
      flash[:notice] = flash_error(t('projects.project_not_found', id: params[:id]))
      redirect_to projects_path
      return nil
    end
    projects.first
  end

  def set_project_type(params_hash, project_type)
    if project_type == 'not_funded'
      params_hash[:type] = "NonFundedProject"
      params_hash[:funder] = nil
      params_hash[:source] = nil
      params_hash.delete(:funders_attributes)
    else
      params_hash[:type] = "FundedProject"
      params_hash[:funder] = params[:project][:funders_attributes]&.values&.first&.dig("id")
    end
  end

  def setup_data_for_edit
    @user_select_list = load_user_select_list
    @usedOntologies = @project.ontologyUsed || []
    @ontologies = LinkedData::Client::Models::Ontology.all
  end

  def load_user_select_list
    users = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
    users.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    users
  end


  def handle_create_response
    if response_success?(@project_saved)
      flash[:notice] = t('projects.project_successfully_created')
      redirect_to project_path(@project.acronym)
    else
      handle_project_save_error(@project_saved)
      @user_select_list = load_user_select_list
      render action: "new"
    end
  end

  def handle_project_save_error(response)
    if response.status == 409
      error = OpenStruct.new existence: t('projects.error_unique_acronym', acronym: params[:project][:acronym])
      @errors = Hash[:error, OpenStruct.new(acronym: error)]
    else
      @errors = response_errors(response)
    end
  end

  def flash_error(msg)
    html = ''.html_safe
    html << '<span style=color:red;>'.html_safe
    html << msg
    html << '</span>'.html_safe
  end


  def api_connection
    @api_connection ||= Faraday.new(url: rest_url) do |faraday|
      faraday.headers['Authorization'] = "apikey token=#{get_apikey}"
      faraday.headers['Accept'] = "application/json"
      faraday.request :url_encoded
      faraday.response :json, content_type: /\bjson$/
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

  def project_params
    params.require(:project).permit(
      :acronym, { creator: [] }, :type, :name, :homePage, :description, 
      { ontologyUsed: [] }, :source, { keywords: [] },
      # Both formats for backward compatibility  
      :contact, { contact: [] },
      :organization, { organization: {} },
      :logo, :grant_number, :start_date, :end_date, :funder,
      { organizations_attributes: [:id] },
      { contacts_attributes: [:id] },
      { funders_attributes: [:id] },
      :project_type
    )
  end
end