class ProjectSearchInputComponent < ViewComponent::Base
  def initialize(id:, name:, selected: nil, placeholder: nil, multiple: true, open_to_add_values: true, ajax_url: nil)
    @id = id
    @name = name
    @selected = Array(selected).map { |v| extract_acronym(v.to_s) }
    @placeholder = placeholder
    @multiple = multiple
    @open_to_add_values = open_to_add_values
    @ajax_url = ajax_url || '/ajax/projects'
  end

  private

  attr_reader :id, :name, :selected, :placeholder, :multiple, :open_to_add_values, :ajax_url

  def extract_acronym(val)
    val.include?('/') ? val.split('/').last : val
  end

  def projects_for_select
    projects = LinkedData::Client::Models::Project.all || []
    options = projects.map { |project| ["#{project.name} (#{project.acronym})", project.acronym] }

    selected.each do |acronym|
      next if options.any? { |opt| opt[1] == acronym }
      
      project = LinkedData::Client::Models::Project.find_by_acronym(acronym)&.first
      options << if project
        ["#{project.name} (#{project.acronym})", acronym]
      else
        [acronym, acronym]
      end
    end

    options
  end
end