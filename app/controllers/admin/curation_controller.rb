# Curation tab of the administration console: every ontology (views, metadata-only and private ones included)
# with the date of its first submission, the fields of its latest submission that are still empty,
# and its current curation (curatedBy / curatedOn)
# Also used by the curators (CURATOR role): the Curation page of the top bar shows the same content (#page)
class Admin::CurationController < ApplicationController
  layout :determine_layout
  before_action :authorize_curation

  ONTOLOGY_ATTRIBUTES = %w[acronym name viewingRestriction].freeze

  # Same tabs, in the same order, as the Edit page (SubmissionsController#edit)
  EDIT_TABS = ['general', 'description', 'dates', 'licensing', 'agents', 'links', 'media', 'community', 'usage',
               'relations', 'content', 'methodology', 'object description properties'].freeze
  # Never asked to the authors: the curation fields (filled in by the system, CurationRecorder), the portal links
  # (greyed for the authors), and the fields the Edit page changes with other inputs
  # (pullLocation: the location of the file, hasDomain: the categories of the ontology)
  NOT_ASKED_ATTRIBUTES = (CurationRecorder::CURATION_ATTRIBUTES + SubmissionInputsHelper::PORTAL_GENERATED_ATTRIBUTES +
                          %w[pullLocation hasDomain]).freeze

  def index
    ontologies = LinkedData::Client::Models::Ontology.all(include: ONTOLOGY_ATTRIBUTES.join(','), also_include_views: true,
                                                          display_links: false, display_context: false)
    ontologies = Array(ontologies).reject(&:errors)

    # The latest submission of each ontology, whatever its status: a new deposit (not processed yet)
    # and a metadata-only entry (its processing always ends in error) are listed too.
    # It is the submission opened by the Edit button of the ontology page.
    attributes = %w[ontology submissionId curatedBy curatedOn] + askable_metadata.map { |metadata| metadata['attribute'].to_s }
    submissions = LinkedData::Client::Models::OntologySubmission.all(include: attributes.uniq.join(','), include_status: 'ANY',
                                                                     also_include_views: true, display_links: false, display_context: false)
    submissions = Array(submissions).map { |s| s[:ontology] ? [s[:ontology][:id], s] : nil }.compact.to_h
    first_dates = first_submission_dates

    # Number of fields counted in the "Empty fields" column: the fields of the "Ask the author" window
    @fields_total = askable_metadata.size
    # Most empty fields first, the ontologies without submission last
    @rows = ontologies.map { |ontology| curation_row(ontology, submissions[ontology.id], first_dates[ontology.acronym]) }
                      .sort_by { |row| [-(row[:empty] || -1), row[:acronym].to_s] }

    # The numbers at the top of the tab
    @kpis = {
      entries: @rows.size,
      empty: @rows.sum { |row| row[:empty].to_i },
      curated: @rows.count { |row| row[:curated] }
    }
  end

  # Curation page of the curators (link "Curation" of the top bar): the same content as the Curation tab
  # of the administration console, as a full page
  def page
    index
    render 'page'
  end

  # "Ask the author" window, step 1: the empty fields of the submission opened by the Curate button
  # (Recommended or not), by tab of the Edit page. The filled fields are checked with the Curate button.
  # fields[]: the fields ticked before going back from step 2
  def ask
    load_ask_fields
    @ticked = Array(params[:fields]).map(&:to_s)
    render 'ask', layout: false
  end

  # Step 2: the email to the administrators of the ontology, pre-filled (in English) with the ticked fields
  def ask_mail
    load_ask_mail
    @subject, @body = default_ask_mail
    @error = t('admin.curation.ask_no_field') if @fields.empty?
    render 'ask_mail', layout: false
  end

  # Sends the email written by the administrator, like the processing emails of the portal:
  # from the support address to the administrators of the ontology, with a copy to the support.
  # Sent now (not in the background) to tell the administrator when it fails.
  def ask_send
    load_ask_mail
    @subject = params[:subject].to_s.strip
    @body = params[:body].to_s.strip
    @error = ask_mail_error
    if @error.nil?
      CurationRequestMailer.ask_author(to: @recipients.map { |admin| admin[:email] }, cc: @support, from: @sender,
                                       subject: @subject, body: @body).deliver_now
      return render 'ask_sent', layout: false
    end

    render 'ask_mail', layout: false, status: :unprocessable_entity
  rescue StandardError => e
    @error = t('admin.curation.ask_send_failed', message: e.message)
    render 'ask_mail', layout: false, status: :unprocessable_entity
  end

  private

  def load_ask_fields
    @acronym = params[:acronym]
    @submission_id = params[:submission_id].to_s
    @ontology = begin
      LinkedData::Client::Models::Ontology.find_by_acronym(@acronym).first
    rescue StandardError
      nil
    end
    submission = ask_submission(@ontology, @submission_id)
    # nil when the submission can not be read
    @fields_by_tab = submission && empty_fields_by_tab(submission)
  end

  # The ticked fields that are still empty and can be asked (the list of the window, in the order of the Edit tabs),
  # the administrators of the ontology, and the addresses of the email
  def load_ask_mail
    load_ask_fields
    ticked = Array(params[:fields]).map(&:to_s)
    @fields = Array(@fields_by_tab).flat_map(&:last).select { |field| ticked.include?(field[:attribute]) }
    @recipients = ontology_admins(@ontology)
    @support = $SUPPORT_EMAIL.to_s.strip.presence
    # Same sender as the processing emails: the support address of the portal (else the sender of the other emails of the site)
    @sender = @support || ApplicationMailer.default[:from]
  end

  def ask_submission(ontology, submission_id)
    return nil if ontology.nil? || submission_id.empty?

    submission = ontology.explore.submissions({ display: 'all' }, submission_id)
    submission.nil? || response_error?(submission) ? nil : submission
  rescue StandardError
    nil
  end

  # [{ username:, email: }] of the administrators of the ontology that have an email address
  def ontology_admins(ontology)
    Array(ontology&.administeredBy).filter_map do |user_id|
      user = LinkedData::Client::Models::User.find(user_id.to_s, include: 'username,email')
      email = user.respond_to?(:email) ? user.email.to_s.strip : ''
      { username: user.username, email: email } unless email.empty?
    rescue StandardError
      nil
    end
  end

  # Subject and text of the email, in English (the authors are not all French speakers); the administrator can change them.
  # The link opens the usual Edit page (all the tabs, with the Recommended badges)
  def default_ask_mail
    I18n.with_locale(:en) do
      values = { portal: helpers.portal_name, name: @ontology&.name.presence || @acronym, acronym: @acronym }
      fields = @fields.map { |field| t('admin.curation.ask_mail.field', label: field[:label], tab: field[:tab].humanize) }
      edit_url = "#{$UI_URL.to_s.chomp('/')}#{edit_ontology_submission_path(@acronym, @submission_id)}"
      [t('admin.curation.ask_mail.subject', **values),
       t('admin.curation.ask_mail.body', **values, fields: fields.join("\n"), edit_url: edit_url)]
    end
  end

  def ask_mail_error
    return t('admin.curation.ask_no_field') if @fields.empty?
    return t('admin.curation.ask_no_recipient', acronym: @acronym) if @recipients.empty?
    return t('admin.curation.ask_empty_mail') if @subject.empty? || @body.empty?

    nil
  end

  # The fields of the Edit tabs that can be asked to the authors: the list of the "Ask the author" window,
  # also counted in the "Empty fields" column of the table
  def askable_metadata
    @askable_metadata ||= helpers.submission_metadata.select do |metadata|
      EDIT_TABS.include?(metadata['category']) && !NOT_ASKED_ATTRIBUTES.include?(metadata['attribute'].to_s)
    end
  end

  # Empty: same rule as the Recommended badges of the Edit page (SubmissionInputsHelper#metadata_value_blank?)
  def empty_field?(submission, attribute)
    value = begin
      submission.send(attribute)
    rescue StandardError
      nil
    end
    helpers.metadata_value_blank?(value)
  end

  # [[tab, [{ attribute:, label:, recommended: }, ...]], ...] for the tabs with at least one empty field.
  # Labels and tab names: the ones of the Edit page (labels of the API, tab names humanized)
  def empty_fields_by_tab(submission)
    fields = askable_metadata.filter_map do |metadata|
      attribute = metadata['attribute'].to_s
      next unless empty_field?(submission, attribute)

      { attribute: attribute, tab: metadata['category'], label: metadata['label'].presence || attribute.humanize,
        recommended: SubmissionInputsHelper::RECOMMENDED_ATTRIBUTES.include?(attribute) }
    end
    EDIT_TABS.map { |tab| [tab, fields.select { |field| field[:tab] == tab }] }.reject { |_tab, list| list.empty? }
  end

  # { acronym => date of the first submission of the ontology }: the Submission date (creationDate) of its oldest
  # version still in the portal (each version has its own date). With a page, the API returns all the submissions,
  # not only the latest ones: one call for all the ontologies.
  def first_submission_dates
    oldest = {}
    page_number = 1
    loop do
      page = LinkedData::Client::HTTP.get('/submissions', { page: page_number, pagesize: 5000, include: 'ontology,submissionId,creationDate',
                                                            include_status: 'ANY', also_include_views: true,
                                                            display_links: false, display_context: false })
      Array(page.respond_to?(:collection) ? page.collection : nil).each do |submission|
        ontology = submission.ontology
        acronym = ontology.respond_to?(:acronym) ? ontology.acronym : ontology.to_s.split('/').last
        oldest[acronym] = submission if oldest[acronym].nil? || submission.submissionId.to_i < oldest[acronym].submissionId.to_i
      end
      break unless page.respond_to?(:nextPage) && page.nextPage

      page_number = page.nextPage
    end
    oldest.transform_values { |submission| date_text(submission.creationDate) }
  rescue StandardError
    {}
  end

  def curation_row(ontology, submission, first_submission_date)
    curated_on = curation_dates(submission)
    curated_by = curation_agents(submission)
    {
      acronym: ontology.acronym,
      name: ontology.name,
      private: ontology.viewingRestriction.eql?('private'),
      first_submission_date: first_submission_date.presence,
      submission_id: submission&.submissionId,
      # Same list and same rule as the "Ask the author" window
      empty: submission && askable_metadata.count { |metadata| empty_field?(submission, metadata['attribute'].to_s) },
      curated_on: curated_on,
      curated_by: curated_by,
      curated: curated_on.any? || curated_by.any?
    }
  end

  # A date of the API without its time, e.g. 2026-11-18
  def date_text(date)
    Date.parse(date.to_s).to_s
  rescue ArgumentError, TypeError
    date.to_s
  end

  # curatedOn is a list of dates in the API
  def curation_dates(submission)
    return [] unless submission

    Array(submission.curatedOn).map { |date| date_text(date) }.reject(&:blank?)
  end

  # curatedBy is a list of Agents (persons or organizations)
  def curation_agents(submission)
    return [] unless submission

    Array(submission.curatedBy).map { |agent| agent_label(agent) }.reject(&:blank?)
  end

  def agent_label(agent)
    return agent.split('/').last if agent.is_a?(String)

    name = begin
      agent.name
    rescue StandardError
      nil
    end
    name.presence || agent.id.to_s.split('/').last
  end
end
