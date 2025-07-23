module OntologyUpdater
  extend ActiveSupport::Concern
  include SubmissionUpdater
  include TurboHelper

  def update_existent_ontology(acronym)
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    return [nil, nil, nil] if @ontology.nil?

    new_values = ontology_params
    project_messages = { success: [], warning: [] }
    
    if params[:ontology].key?(:projects)
      project_messages = handle_project_updates(new_values[:projects] || [])
      new_values = new_values.except(:projects)
    end

    filtered_values = new_values.reject { |k, v| v.blank? || (v.is_a?(Array) && v.all?(&:blank?)) }
    
    result = true
    if filtered_values.present?
      filtered_values.each do |key, values|
        if values.is_a?(Array)
          values = values.reject(&:blank?)
        end
        @ontology.send("#{key}=", values)
      rescue StandardError => e
        next
      end
      
      begin
        result = @ontology.update(values: filtered_values, cache_refresh_all: false)
      rescue StandardError => e
        result = false
      end
    end

    [@ontology, result, project_messages]
  end

  private

  def handle_project_updates(new_project_acronyms)
    return { success: [], warning: [] } unless @ontology

    old_project_uris = load_ontology_projects(@ontology)
    new_project_acronyms = (new_project_acronyms || []).reject(&:blank?)
    
    ontology_uri = @ontology.id.to_s
    normalized_ontology_uri = normalize_uri(ontology_uri)

    invalid_projects = []
    new_project_acronyms.each do |project_acronym|
      next if project_acronym.blank?
      begin
        projects = LinkedData::Client::Models::Project.find_by_acronym(project_acronym)
        if projects.nil? || projects.empty?
          invalid_projects << project_acronym
        end
      rescue
        invalid_projects << project_acronym
      end
    end

    if invalid_projects.any?
      return {
        success: [],
        warning: ["Invalid project(s): #{invalid_projects.join(', ')}. Please ensure all projects exist before saving."]
      }
    end

    successful_additions = []
    failed_additions = []
    successful_removals = []
    failed_removals = []

    # Add new projects
    new_project_acronyms.each do |project_acronym|
      next if project_acronym.blank?
      begin
        projects = LinkedData::Client::Models::Project.find_by_acronym(project_acronym)
        next if projects.nil? || projects.empty?
        
        project = projects.first
        project.ontologyUsed ||= []
        project_ontology_uris = project.ontologyUsed.map { |uri| normalize_uri(uri) }
        
        unless project_ontology_uris.include?(normalized_ontology_uri)
          project.ontologyUsed << ontology_uri
          normalize_project_references(project)
          
          result = project.update(values: { ontologyUsed: project.ontologyUsed })
          if result && !result.is_a?(FalseClass) && !(result.respond_to?(:errors) && result.errors&.any?)
            successful_additions << project
          else
            failed_additions << project
          end
        else
          successful_additions << project
        end
      rescue => e
        failed_project = projects&.first || OpenStruct.new(acronym: project_acronym)
        failed_additions << failed_project
        project = failed_project
        admin_emails = []
        creator_email = nil
        if project.respond_to?(:admin) && project.admin
          admin_emails = Array(project.admin).map do |admin_id|
            user = LinkedData::Client::Models::User.find(admin_id).first rescue nil
            user&.email
          end.compact
        end
        if project.respond_to?(:creator) && project.creator
          creator_id = Array(project.creator).first
          user = LinkedData::Client::Models::User.find(creator_id).first rescue nil
          creator_email = user&.email
        end
        recipients = (admin_emails + [creator_email]).compact.uniq

        OntologyProjectRequestMailer.project_access_request(
          project: project,
          ontology: @ontology,
          user: (defined?(current_user) ? current_user : nil),
          action: 'add',
          recipients: recipients
        ).deliver_later if recipients.any?
      end
    end

    # Remove old projects
    old_project_uris = Array(old_project_uris).compact.reject(&:blank?).select { |uri| uri.is_a?(String) && uri.include?('/') }
    old_project_acronyms = old_project_uris.map { |uri| uri.split('/').last }.compact
    removed_project_acronyms = old_project_acronyms - new_project_acronyms

    removed_project_acronyms.each do |project_acronym|
      next if project_acronym.blank?
      begin
        projects = LinkedData::Client::Models::Project.find_by_acronym(project_acronym)
        next if projects.nil? || projects.empty?
        
        project = projects.first
        project.ontologyUsed ||= []
        
        if project.ontologyUsed.any? { |uri| normalize_uri(uri) == normalized_ontology_uri }
          project.ontologyUsed = project.ontologyUsed.reject { |uri| normalize_uri(uri) == normalized_ontology_uri }
          normalize_project_references(project)
          
          result = project.update(values: { ontologyUsed: project.ontologyUsed })
          if result && !result.is_a?(FalseClass) && !(result.respond_to?(:errors) && result.errors&.any?)
            successful_removals << project
          else
            failed_removals << project
          end
        else
          successful_removals << project
        end
      rescue => e
        failed_project = projects&.first || OpenStruct.new(acronym: project_acronym)
        failed_removals << failed_project
        project = failed_project
        admin_emails = []
        creator_email = nil
        if project.respond_to?(:admin) && project.admin
          admin_emails = Array(project.admin).map do |admin_id|
            user = LinkedData::Client::Models::User.find(admin_id).first rescue nil
            user&.email
          end.compact
        end
        if project.respond_to?(:creator) && project.creator
          creator_id = Array(project.creator).first
          user = LinkedData::Client::Models::User.find(creator_id).first rescue nil
          creator_email = user&.email
        end
        recipients = (admin_emails + [creator_email]).compact.uniq

        OntologyProjectRequestMailer.project_access_request(
          project: project,
          ontology: @ontology,
          user: (defined?(current_user) ? current_user : nil),
          action: 'remove',
          recipients: recipients
        ).deliver_later if recipients.any?

      end
    end

    build_project_update_messages(successful_additions, failed_additions, successful_removals, failed_removals)
  end

  def build_project_update_messages(successful_additions, failed_additions, successful_removals, failed_removals)
    messages = { success: [], warning: [] }

    if failed_additions.any?
      project_names = failed_additions.map { |p| p.acronym }.join(', ')
      messages[:warning] << I18n.t('submissions.project_updates.add_failed_with_projects', projects: project_names)
    end

    if failed_removals.any?
      project_names = failed_removals.map { |p| p.acronym }.join(', ')
      messages[:warning] << I18n.t('project_updates.remove_failed_with_projects', projects: project_names)
    end

    messages
  end

  def normalize_uri(uri)
    uri.to_s.chomp('/').split('#').first.split('?').first
  end

  def normalize_project_references(project)
    project.organization = project.organization&.id if project.organization.respond_to?(:id)
    project.funder = project.funder&.id if project.funder.respond_to?(:id)
  end

  def load_ontology_projects(ontology)
    full_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ontology.acronym, include: 'projects').first
    Array(full_ontology&.projects).compact.select { |p| p.is_a?(String) }
  rescue
    []
  end

  public

  def ontology_from_params
    ontology = LinkedData::Client::Models::Ontology.new(values: ontology_params)
    ontology.viewOf = nil unless ontology.isView
    ontology
  end

  def ontology_params
    return {} unless params[:ontology]

    p = params.require(:ontology).permit(
      :name, :acronym, { administeredBy: [] }, :viewingRestriction, { acl: [] },
      { hasDomain: [] }, :viewOf, :isView, :subscribe_notifications, 
      { group: [] }, { categories: [] }, { projects: [] }
    )

    p[:administeredBy].reject!(&:blank?) if p[:administeredBy]
    p[:hasDomain].reject!(&:blank?) if p[:hasDomain]
    p[:group].reject!(&:blank?) if p[:group]
    p[:categories].reject!(&:blank?) if p[:categories]
    p[:projects].reject!(&:blank?) if p[:projects]
    p[:acl].reject!(&:blank?) if p[:acl]
    
    p[:viewOf] = '' if p.key?(:viewOf) && !p.key?(:isView)
    p.to_h
  end

  def show_new_errors(object, redirection = 'ontologies/new')
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