# app/components/project_browse_card_component.rb
class ProjectBrowseCardComponent < ViewComponent::Base
  def initialize(project:, ontologies_hash: {})
    @project = project
    @ontologies_hash = ontologies_hash

  end

  private

  attr_reader :project, :ontologies_hash

  def project_link
    helpers.project_path(project.acronym)
  end

  def ontology_count
    project.ontologyUsed&.count { |ont| ontologies_hash[ont] } || 0
  end

  def style_bg
    "background-color: var(--light-color); color: var(--primary-color);"
  end
end