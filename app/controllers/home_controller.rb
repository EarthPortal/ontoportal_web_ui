# frozen_string_literal: true

class HomeController < ApplicationController
  layout :determine_layout

  include FairScoreHelper, FederationHelper,MetricsHelper

  def index
    @analytics = helpers.ontologies_analytics

    @slices = LinkedData::Client::Models::Slice.all

    @metrics = portal_metrics(@analytics)


    @upload_benefits = [
      t('home.benefit1'),
      t('home.benefit2'),
      t('home.benefit3'),
      t('home.benefit4'),
      t('home.benefit5')
    ]

    @anal_ont_names = []
    @anal_ont_numbers = []
    if @analytics.empty?
      all_metrics = LinkedData::Client::Models::Metrics.all
      all_metrics.sort_by{|x| -(x.classes + x.individuals)}[0..4].each do |x|
        @anal_ont_names << x.id.split('/')[-4]
        @anal_ont_numbers << (x.classes + x.individuals) || 0
      end
    else
      @analytics.sort_by{|ont, count| -count}[0..4].each do |ont, count|
        @anal_ont_names << ont
        @anal_ont_numbers << count
      end
    end


  end

  def set_cookies
    cookies.permanent[:cookies_accepted] = params[:cookies] if params[:cookies]
    render 'cookies', layout: nil
  end

  def portal_config
    @config = $PORTALS_INSTANCES.select { |x| x[:name].downcase.eql?((params[:portal] || helpers.portal_name).downcase) }.first
    if @config && @config[:api]
      @portal_config = LinkedData::Client::Models::Ontology.top_level_links(@config[:api]).to_h
      @color = @portal_config[:color].present? ? @portal_config[:color] : @config[:color]
      @name = @portal_config[:title].present? ? @portal_config[:title] : @config[:name]
    else
      @portal_config = {}
    end
  end

  def tools
    @tools = {
      search: {
        link: "search/ontologies/content",
        icon: "icons/search.svg",
        title: t('tools.search.title'),
        description: t('tools.search.description'),
      },
      converter: {
        link: "/content_finder",
        icon: "icons/settings.svg",
        title: t('tools.converter.title'),
        description: t('tools.converter.description'),
      },
      url_checker: {
        link: check_resolvability_path,
        icon: "check.svg",
        title: t('tools.url_checker.title'),
        description: t('tools.url_checker.description')
      }
    }

    @title = "#{helpers.portal_name} #{t('layout.footer.tools')}"
    render 'tools', layout: 'tool'
  end

  def all_resources
    @conceptid = params[:conceptid]
    @ontologyid = params[:ontologyid]
    @ontologyversionid = params[:ontologyversionid]
    @search = params[:search]
  end

  def feedback
    feedback_layout = params[:pop].eql?('true') ? 'popup' : 'ontology'
    
    # Skip processing if form not submitted
    return render('home/feedback/feedback', layout: feedback_layout) if params[:sim_submit].nil?
  
    @errors = []
    
    # Validation
    @errors << t('home.include_email') if invalid_email?(params[:email])
    @errors << t('home.include_name') if params[:name].blank?
    @errors << t('home.include_slice_name') if params[:slice_name].blank?
    @errors << t('home.include_ontologies') if params[:ontologies].blank?
    @errors << t('home.include_comment') if params[:comment].blank?
  
    # Captcha validation for non-logged in users
    if using_captcha? && !session[:user]
      @errors << t('home.fill_captcha') unless verify_recaptcha
    end
  
    # Re-render form if errors exist
    if @errors.any?
      return render('home/feedback/feedback', layout: feedback_layout)
    end
  
    # Process feedback
    Notifier.feedback(
      params[:name], 
      params[:email], 
      params[:comment], 
      params[:slice_name], 
      params[:ontologies]
    ).deliver_later
  
    # Response based on popup status
    if params[:pop].eql?('true')
      render 'home/feedback/feedback_complete', layout: 'popup'
    else
      flash[:notice] = t('home.notice_feedback')
      redirect_to_home
    end
  end
  
  private
  
  def invalid_email?(email)
    email.blank? || !email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def site_config
    render json: bp_config_json
  end

  def feedback_complete; end

  def annotator_recommender_form
    if params[:submit_button] == "annotator"
      redirect_to "/annotator?text=#{helpers.escape(params[:input])}"
    elsif params[:submit_button] == "recommender"
      redirect_to "/recommender?input=#{helpers.escape(params[:input])}"
    end
  end


  def federation_portals_status
    @name = params[:name]
    @acronym = params[:acronym]
    @key = params[:portal_name]
    @checked = params[:checked].eql?('true')
    @portal_up = federation_portal_status(portal_name: @key.downcase.to_sym)
    render inline: helpers.federation_chip_component(@key, @name, @acronym, @checked, @portal_up)
  end

  private

  # Dr. Musen wants 5 specific groups to appear first, sorted by order of importance.
  # Ordering is documented in GitHub: https://github.com/ncbo/bioportal_web_ui/issues/15.
  # All other groups come after, with agriculture in the last position.
  def organize_groups
    # Reference: https://lildude.co.uk/sort-an-array-of-strings-by-severity
    acronyms = %w[UMLS OBO_Foundry WHO-FIC CTSA caBIG]
    size = @groups.size
    @groups.sort_by! { |g| acronyms.find_index(g.acronym[/(UMLS|OBO_Foundry|WHO-FIC|CTSA|caBIG)/]) || size }

    others, agriculture = @groups.partition { |g| g.acronym != 'CGIAR' }
    @groups = others + agriculture
  end
end
