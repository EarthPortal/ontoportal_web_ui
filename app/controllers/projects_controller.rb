class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.xml

  layout :determine_layout

  def index
    @projects = LinkedData::Client::Models::Project.all
    @projects.reject! { |p| p.name.nil? }
    @projects.sort! { |a,b| a.name.downcase <=> b.name.downcase }
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true)
    @ontologies_hash = Hash[@ontologies.map {|ont| [ont.id, ont]}]
    if request.xhr?
      render action: "index", layout: false
    else
      render action: "index"
    end
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
    
    filtered_params = {}
    filtered_params[:name] = project_params[:name] if project_params[:name].present?
    filtered_params[:description] = project_params[:description] if project_params[:description].present?
    filtered_params[:homePage] = project_params[:homePage] if project_params[:homePage].present?
    filtered_params[:logo] = project_params[:logo] if project_params[:logo].present?
    
    if project_params[:keywords].present?
      filtered_params[:keywords] = project_params[:keywords].is_a?(Array) ? 
                                project_params[:keywords].reject(&:blank?) : 
                                [project_params[:keywords]].reject(&:blank?)
    end
    
    if project_params[:ontologyUsed].present?
      filtered_params[:ontologyUsed] = project_params[:ontologyUsed].reject(&:blank?)
    end
    
    filtered_params[:start_date] = project_params[:start_date] if project_params[:start_date].present?
    filtered_params[:end_date] = project_params[:end_date] if project_params[:end_date].present?
    
    @project.update_from_params(filtered_params)
    
    @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
    @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    @usedOntologies = @project.ontologyUsed&.map{|o| o.split('/').last} || []
    @ontologies = LinkedData::Client::Models::Ontology.all
    
    begin
      update_url = "/projects/#{@project.acronym}"
      response = LinkedData::Client::HTTP.patch(update_url, filtered_params)
      
      if LinkedData::Client.respond_to?(:clear_cache)
        LinkedData::Client.clear_cache
      elsif LinkedData::Client::HTTP.respond_to?(:clear_cache)
        LinkedData::Client::HTTP.clear_cache
      end
      
      flash[:notice] = t('projects.project_successfully_updated')
      redirect_to project_path(@project.acronym)
    rescue => e
      @errors = {error: {general: OpenStruct.new(existence: "Error updating project: #{e.message}")}}
      render :edit
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
              agent_response = api_connection.get("/agents/#{agent_id}")
              project["funder"] = agent_response.body if agent_response.status == 200 && agent_response.body
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

  def project_params
    params.require(:project).permit(
      :acronym, { creator: [] }, :type, :name, :homePage, :description, 
      { ontologyUsed: [] }, :source, { keywords: [] }, :contact, :organization, 
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
end