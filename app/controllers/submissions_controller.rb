class SubmissionsController < ApplicationController
  include SubmissionsHelper, SubmissionUpdater, OntologyUpdater
  layout :determine_layout
  before_action :authorize_and_redirect, :only => [:edit, :update, :create, :new]
  before_action :authorize_read_only, :only => [:new, :create, :edit, :update]
  before_action :submission_metadata, only: [:create, :edit, :new, :update, :index]
  

  def index
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first

    ontology_not_found(params[:ontology_id]) if @ontology.nil?

    @ont_restricted = ontology_restricted?(@ontology.acronym)

    # Retrieve submissions in descending submissionId order (should be reverse chronological order)
    @submissions = @ontology.explore.submissions({include: "submissionId,creationDate,released,modificationDate,submissionStatus,hasOntologyLanguage,version,diffFilePath,ontology", invalidate_cache: invalidate_cache?})
                            .sort {|a,b| b.submissionId.to_i <=> a.submissionId.to_i } || []

    LOG.add :error, t('submissions.no_submissions_for_ontology', ontology: @ontology.id) if @submissions.empty?
    render :index, layout: nil
  end

  # When getting "Add submission" form to display
  def new
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    @submission = @ontology.explore.latest_submission || LinkedData::Client::Models::OntologySubmission.new
    @submission.id = nil
    @categories = LinkedData::Client::Models::Category.all
    @groups = LinkedData::Client::Models::Group.all
    @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
    @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
    @is_update_ontology = true
    render "ontologies/new"
  end

  # Called when form to "Add submission" is submitted
  def create
    @is_update_ontology = true

    if params[:ontology]
      @ontology, response = update_existent_ontology(params[:ontology_id])

      if response.nil? || response_error?(response)
        show_new_errors(response)
        return
      end
    end
    @submission = @ontology.explore.latest_submission({ display: 'all' })
    @submission = save_submission(new_submission_hash(@ontology, @submission))

    if response_error?(@submission)
      show_new_errors(@submission)
    else
      redirect_to "/ontologies/success/#{@ontology.acronym}"
    end
  end

  # Called when form to "Edit submission" is submitted
  def edit_properties
    display_submission_attributes params[:ontology_id], params[:properties]&.split(','), submissionId: params[:submission_id],
                                  inline_save: params[:inline_save]&.eql?('true')

    attribute_template_output = render_to_string(inline: helpers.render_submission_inputs(params[:container_id] || 'metadata_by_ontology', @submission))

    render inline: attribute_template_output

  end

  def edit
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    ontology_not_found(params[:ontology_id]) unless @ontology
    category_attributes = submission_metadata.group_by{|x| x['category']}.transform_values{|x| x.map{|attr| attr['attribute']} }
    category_attributes = category_attributes.reject{|key| ['no'].include?(key.to_s)}
    category_attributes['general'] << %w[acronym name groups administeredBy categories]
    category_attributes['licensing'] << 'viewingRestriction'
    category_attributes['relations'] << 'viewOf'
    category_attributes['community'] << 'projects'
    @selected_attributes = Array(params[:properties])
    if @selected_attributes.empty?
      @categories_order = ['general', 'description', 'dates', 'licensing', 'persons and organizations', 'links', 'media', 'community', 'usage' ,'relations', 'content','methodology', 'object description properties']
      @category_attributes = category_attributes
    end
    render 'submissions/edit', layout: params[:container_id] ?  nil : 'ontology'
  end

  # When editing a submission (called when submit "Edit submission information" form)
  def update
    @is_update_ontology = true
    acronym = params[:ontology_id]
    submission_id = params[:id]
    if params[:ontology]
      @ontology, response, project_messages = update_existent_ontology(acronym)

      if response.nil? || response_error?(response)
        show_new_errors(response, partial: 'submissions/form_content', id: 'test')
        return
      else
        if project_messages && project_messages[:warning].any?
          all_warnings = Array(flash[:alert]) + Array(project_messages[:warning])
          flash[:alert] = all_warnings.uniq.join(' ')
        elsif project_messages && project_messages[:success].any?
          project_messages[:success].each { |msg| flash[:notice] = [flash[:notice], msg].compact.join(' ') }
        end
      end
    end

    if params[:submission].nil?
      if defined?(project_messages) && project_messages
        if project_messages[:warning].any?
          all_warnings = Array(flash[:alert]) + Array(project_messages[:warning])
          flash[:alert] = all_warnings.uniq.join(' ')
        elsif project_messages[:success].any?
          project_messages[:success].each { |msg| flash[:notice] = [flash[:notice], msg].compact.join(' ') }
        end
      end
      return redirect_to "/ontologies/#{acronym}",
                         notice: t('submissions.submission_updated_successfully')
    end

    @submission, response = update_submission(update_submission_hash(acronym), submission_id, @ontology)
    if params[:attribute].nil?
      if response_error?(response)
        show_new_errors(response, partial: 'submissions/form_content', id: 'test')
      else
        if defined?(project_messages) && project_messages
          if project_messages[:warning].any?
            all_warnings = Array(flash[:alert]) + Array(project_messages[:warning])
            flash[:alert] = all_warnings.uniq.join(' ')
          elsif project_messages[:success].any?
            project_messages[:success].each { |msg| flash[:notice] = [flash[:notice], msg].compact.join(' ') }
          end
        end
        redirect_to "/ontologies/#{acronym}",
                    notice: t('submissions.submission_updated_successfully'), status: :see_other
      end
    else
      @errors = response_errors(response) if response_error?(response)
      @submission = submission_from_params(params[:submission])
      @submission.submissionId = submission_id
      reset_agent_attributes
      render_submission_attribute(params[:attribute])
    end

  end


end
