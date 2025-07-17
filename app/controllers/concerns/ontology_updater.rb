module OntologyUpdater
  extend ActiveSupport::Concern
  include SubmissionUpdater
  include TurboHelper

  def update_existent_ontology(acronym)
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    return nil if @ontology.nil?

    old_project_uris = load_ontology_projects(@ontology)
    new_values = ontology_params
    projects_param_included = params[:ontology].key?(:projects)
    new_project_acronyms = projects_param_included ? 
      (new_values[:projects] || []) : 
      old_project_uris.map { |uri| uri.split('/').last }.compact
    
    ontology_uri = @ontology.id.to_s
    normalized_ontology_uri = normalize_uri(ontology_uri)

    # Add ontology to new projects
    new_project_acronyms.each do |project_acronym|
      begin
        projects = LinkedData::Client::Models::Project.find_by_acronym(project_acronym)
        next if projects.nil? || projects.empty?
        
        project = projects.first
        project.ontologyUsed ||= []
        project_ontology_uris = project.ontologyUsed.map { |uri| normalize_uri(uri) }
        
        unless project_ontology_uris.include?(normalized_ontology_uri)
          project.ontologyUsed << ontology_uri
          normalize_project_references(project)
          project.update(values: { ontologyUsed: project.ontologyUsed })
        end
      rescue => e
        Rails.logger.error "Error adding ontology to project #{project_acronym}: #{e.message}"
      end
    end

    # Remove ontology from projects no longer associated
    old_project_uris = Array(old_project_uris).compact.reject(&:blank?).select { |uri| uri.is_a?(String) && uri.include?('/') }
    old_project_acronyms = old_project_uris.map { |uri| uri.split('/').last }.compact
    removed_project_acronyms = old_project_acronyms - new_project_acronyms

    removed_project_acronyms.each do |project_acronym|
      begin
        projects = LinkedData::Client::Models::Project.find_by_acronym(project_acronym)
        next if projects.nil? || projects.empty?
        
        project = projects.first
        project.ontologyUsed ||= []
        
        if project.ontologyUsed.any? { |uri| normalize_uri(uri) == normalized_ontology_uri }
          project.ontologyUsed = project.ontologyUsed.reject { |uri| normalize_uri(uri) == normalized_ontology_uri }
          normalize_project_references(project)
          project.update(values: { ontologyUsed: project.ontologyUsed })
        end
      rescue => e
        Rails.logger.error "Error removing ontology from project #{project_acronym}: #{e.message}"
      end
    end

    # Update other ontology fields
    other_values = new_values.except(:projects)
    result = if other_values.present?
      other_values.each { |key, values| @ontology.send("#{key}=", values) rescue nil }
      @ontology.update(values: other_values, cache_refresh_all: false)
    else
      true
    end
    
    [@ontology, result]
  end

  private

  def normalize_uri(uri)
    uri.to_s.chomp('/').split('#').first.split('?').first
  end

  def normalize_project_references(project)
    project.organization = project.organization&.id if project.organization.respond_to?(:id)
    project.funder = project.funder&.id if project.funder.respond_to?(:id)
  end

  def load_ontology_projects(ontology)
    begin
      # Direct API approach - most reliable method
      full_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ontology.acronym, include: 'projects').first
      projects = Array(full_ontology&.projects).compact.select { |p| p.is_a?(String) }
      return projects
    rescue => e
      Rails.logger.error "Error loading projects for ontology #{ontology.acronym}: #{e.message}"
      return []
    end
  end


  def ontology_from_params
    ontology = LinkedData::Client::Models::Ontology.new(values: ontology_params)
    ontology.viewOf = nil unless ontology.isView
    ontology
  end

  def ontology_params
    return {} unless params[:ontology]

    p = params.require(:ontology).permit(:name, :acronym, { administeredBy: [] }, :viewingRestriction, { acl: [] },
                                         { hasDomain: [] }, :viewOf, :isView, :subscribe_notifications, { group: [] }, { projects: [] })

    p[:administeredBy].reject!(&:blank?) if p[:administeredBy]
    # p[:acl].reject!(&:blank?)
    p[:hasDomain].reject!(&:blank?) if p[:hasDomain]
    p[:group].reject!(&:blank?) if p[:group]
    p[:viewOf] = '' if p.key?(:viewOf) && !p.key?(:isView)
    p.to_h
  end

  def show_new_errors(object, redirection = 'ontologies/new')
    # TODO optimize
    @ontologies = LinkedData::Client::Models::Ontology.all(include: 'acronym', include_views: true, display_links: false, display_context: false)
    @categories = LinkedData::Client::Models::Category.all
    @groups = LinkedData::Client::Models::Group.all(display_links: false, display_context: false)
    @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
    @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    @errors = response_errors(object)
    @selected_attributes = (Array(errors_attributes) + Array(params[:submission]&.keys)).uniq
    @ontology = ontology_from_params if @ontology.nil?

    @submission = submission_from_params(params[:submission]) if params[:submission] && (@submission.nil? || @submission.errors)
    
    reset_agent_attributes
    if redirection.is_a?(Hash) && redirection[:id]
      render_turbo_stream replace(redirection[:id], partial: redirection[:partial])
    else
      render redirection, status: 422
    end
  end

  def errors_attributes
    @errors = @errors[:error] if @errors && @errors[:error]
    @errors.keys.map(&:to_s) if @errors.is_a?(Hash)
  end

  def new_submission_hash(ontology, submission = nil)
    @submission = submission
    new_submission_params = submission_params(params[:submission])

    if @submission
      old_submission_values = @submission.to_hash.delete_if {  |k, v| !copyable_submission_params?(k, v)}
      new_submission_params = ActionController::Parameters.new(old_submission_values.merge(new_submission_params))
      new_submission_params = submission_params(new_submission_params)
    end

    new_submission_params.delete 'submissionId'
    new_submission_params[:ontology] = ontology.acronym
    ActionController::Parameters.new(new_submission_params)
  end

  def update_submission_hash(acronym)
    submission_params = submission_params(params[:submission])
    submission_params[:ontology] = acronym
    submission_params
  end

  private
  def reset_agent_attributes
    helpers.agent_attributes.each do |attr|
      current_val = @submission[attr]
      new_values = Array(current_val).map do |x|
        next x if x.is_a?(LinkedData::Client::Models::Agent)
        LinkedData::Client::Models::Agent.find(x.split('/').last)
      end

      new_values = new_values.first unless current_val.is_a?(Array)

      @submission[attr] = new_values
    end
  end

  def copyable_submission_params?(key, value)
    return false if value.nil? || (value.respond_to?(:empty?) && value.empty?)

    attr_to_not_copy = [:versionIRI, :version, :deprecated, :valid, :curatedOn,
                        :pullLocation, :metadataVoc, :hasPriorVersion, :creationDate,
                        :submissionStatus]

    !attr_to_not_copy.include?(key.to_sym)
  end
end
