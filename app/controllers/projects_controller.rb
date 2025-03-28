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

    @project = LinkedData::Client::Models::Project.new(values: project_params)
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

    @project = LinkedData::Client::Models::Project.new(values: project_params)
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
    # Get search parameters
    source = params[:source]
    search_term = params[:term]
    search_type = params[:type] || "acronym"
    dataset = params[:dataset] || "data1"
    
    # Initialize response variables
    success = false
    results = []
    message = "No results found"
    
    # Exit early if required parameters are missing
    if source.blank? || search_term.blank?
      render json: { success: false, results: [], message: "Missing required parameters" }
      return
    end
    
    
    begin
      # Build the API URL
      endpoint = "/connector/projects"
      
      # Make the API call
      response = api_connection.get(endpoint) do |req|
        req.params[search_type.to_sym] = search_term
        req.params[:source] = source
      end
      
      # Simple status code handling
      case response.status
      when 200
        # Success - we have results
        success = true
        results = response.body["projects"] || []
        message = results.any? ? "Found #{results.length} projects" : "No projects found"
      
      when 404
        # Not found - return the API error message
        message = "No projects found matching search criteria"
      
      else
        # Other errors
        message = "API Error: HTTP #{response.status}"
      end
      
    rescue Faraday::ConnectionFailed => e
      message = "Connection to API failed"
    rescue => e
      message = "An error occurred"
    end
    
    # Return the response
    render json: {
      success: success,
      results: results,
      message: message
    }
  end

  private

  def project_params
    p = params.require(:project).permit(:name, :acronym, :institution, :contacts, { creator:[] }, :homePage,
                                        :description, { ontologyUsed:[] })
                                        
    p[:creator]&.reject!(&:blank?)
    p[:ontologyUsed] ||= []
    p = p.to_h
  end

  def flash_error(msg)
    html = ''.html_safe
    html << '<span style=color:red;>'.html_safe
    html << msg
    html << '</span>'.html_safe
  end

  # Create a shared connection instance for better performance
  def api_connection
    api_host = ENV.fetch('API_HOST', '172.17.0.1')
    api_port = ENV.fetch('API_PORT', '9393')
    api_url = "http://#{api_host}:#{api_port}"
    
    Rails.logger.info("Connecting to API at: #{api_url}")
  
    @api_connection ||= Faraday.new(api_url) do |faraday|
      faraday.request :url_encoded
      
      # Make sure the order of middleware is correct
      faraday.response :json, content_type: /\bjson$/
            
      # Set longer timeouts for development
      faraday.options[:timeout] = 30
      faraday.options[:open_timeout] = 10
      
      # Use the default adapter
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
    
    # Always return JSON for error responses
    respond_to do |format|
      format.json { render json: { success: false, results: [], message: message } }
      format.html { render json: { success: false, results: [], message: message } }
    end
  end

end
