module FairScoreHelper

  def user_apikey
    session[:user].nil? ? '' : session[:user].apikey
  end

  def fairness_service_enabled?
    !$FAIRNESS_DISABLED
  end

  def get_fairness_service_url(apikey = user_apikey)
    "#{$FAIRNESS_URL}?portal=#{$HOSTNAME.split('.')[0]}#{apikey.nil? || apikey.empty? ? '' : "&apikey=#{apikey}"}"
  end

  def get_fairness_json(ontologies_acronyms, apikey = user_apikey)
    Rails.cache.fetch("fairness-#{ontologies_acronyms.gsub(',', '-')}", expires: 24.hours) do
      begin
        out = {}
        time = Benchmark.realtime do
          conn = Faraday.new do |conn|
            conn.options.timeout = 30
          end
          response = conn.get(get_fairness_service_url(apikey) + "&ontologies=#{ontologies_acronyms}&combined")
          out = MultiJson.load(response.body.force_encoding('ISO-8859-1').encode('UTF-8'))
        end
        puts "Call fairness service for: #{ontologies_acronyms} (#{time}s)"
      rescue
        Rails.logger.warn t('fair_score.fairness_unreachable_warning')
      end

      out
    end
  end

  def get_fair_score(ontologies_acronyms, apikey = user_apikey)
    get_fairness_json(ontologies_acronyms, apikey)['ontologies']
  end

  def get_fair_combined_score(ontologies_acronyms, apikey = user_apikey)
    get_fairness_json(ontologies_acronyms, apikey)['combinedScores']
  end

  

  def create_fair_scores_data(fair_scores, count = nil)
    return nil if fair_scores.nil?

    fair_scores_data = {}
    fair_scores_data[:principles] = {labels:[] , scores:[] , normalizedScores: [] , maxCredits: [] , portalMaxCredits: []}
    fair_scores_data[:criteria] = { labels:[] , scores:[] , normalizedScores: [] , portalMaxCredits: [], questions: [] ,maxCredits: [] , descriptions: []}
    fair_scores_data[:score] = fair_scores['score'].to_f.round(2)
    fair_scores_data[:normalizedScore] = fair_scores['normalizedScore'].to_f.round(2)
    fair_scores_data[:minScore] = fair_scores['minScore'].to_f.round(2)
    fair_scores_data[:maxScore] = fair_scores['maxScore'].to_f.round(2)
    fair_scores_data[:medianScore] = fair_scores['medianScore'].to_f.round(2)
    fair_scores_data[:maxCredits] = fair_scores['maxCredits'].to_i
    fair_scores_data[:resourceCount] = count unless  count.nil?

    fair_scores.to_h.select { |k,v| (v.is_a? Hash) }.each do |key, principle|

      fair_scores_data[:principles][:labels] << key
      fair_scores_data[:principles][:scores] << (principle['score'].to_f.round(2))
      fair_scores_data[:principles][:normalizedScores] << (principle['normalizedScore'].to_f.round(2))
      fair_scores_data[:principles][:maxCredits] << principle['maxCredits']
      fair_scores_data[:principles][:portalMaxCredits] << principle['portalMaxCredits']

      principle.to_h.select { |k,v| (v.is_a? Hash)  }.each do  |key , criterion|
        fair_scores_data[:criteria][:labels] << key
        fair_scores_data[:criteria][:descriptions] << criterion['label']
        fair_scores_data[:criteria][:scores] << (criterion['score'].to_f.round(2))
        fair_scores_data[:criteria][:normalizedScores] << (criterion['normalizedScore'].to_f.round(2))

        fair_scores_data[:criteria][:questions] << criterion['results']

        fair_scores_data[:criteria][:maxCredits] << criterion['maxCredits']
        fair_scores_data[:criteria][:portalMaxCredits] << criterion['portalMaxCredits']
      end
    end
    fair_scores_data
  end

  def get_not_obtained_score(fair_scores_data, index)
    fair_scores_data[:criteria][:portalMaxCredits][index] - fair_scores_data[:criteria][:scores][index]
  end

  def get_not_obtained_score_normalized(fair_scores_data, index)
    score_rest = get_rest_score(fair_scores_data,index)
    not_obtained_score = get_not_obtained_score(fair_scores_data , index)

    if  not_obtained_score.positive? && score_rest.positive?
      ((not_obtained_score / fair_scores_data[:criteria][:maxCredits][index]) * 100).round()
    elsif score_rest.zero?
        100 - fair_scores_data[:criteria][:normalizedScores][index]
    else
      0
    end

  end

  def get_rest_score(fair_scores_data, index)
    fair_scores_data[:criteria][:maxCredits][index] - fair_scores_data[:criteria][:portalMaxCredits][index]
  end

  def get_rest_score_normalized(fair_scores_data, index)
    score_rest = get_rest_score(fair_scores_data ,index)
    not_obtained_score_normalized = get_not_obtained_score_normalized(fair_scores_data , index)

    if score_rest.positive?
      100 - not_obtained_score_normalized - fair_scores_data[:criteria][:normalizedScores][index]
    else
      0
    end

  end

  def not_implemented?(question)
    properties = question['properties']
    score = question ['score']
    (properties.nil? || properties.empty?) && score.zero?
  end

  def default_score?(question)
    properties = question['properties']
    score = question ['score']

    (properties.nil? || properties.empty?) && score.positive?
  end

  def get_name_with_out_dot(name)
    name.to_s.gsub(/\./,'')
  end

  def print_score(score)
    number_with_precision(score, precision: 2, strip_insignificant_zeros: true)
  end

  def fairness_link(style: '', ontology: nil)
    custom_style = "font-size: 50px; line-height: 0.5; margin-left: 6px; #{style}".strip
    ontology = ontology || 'all'
    render IconWithTooltipComponent.new(icon: "json.svg",link: "#{get_fairness_service_url}&ontologies=#{ontology}&combined=true", target: '_blank', title: t('fair_score.go_to_api'), size:'small', style: custom_style)  
  end
end

