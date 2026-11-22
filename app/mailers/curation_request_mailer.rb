# Email of the "Ask the author" window of the Curation tab (Admin::CurationController#ask_send): the text written by
# the administrator, sent like the processing emails of the portal: from the support address of the portal
# to the administrators of the ontology, with a copy to the support
class CurationRequestMailer < ApplicationMailer
  def ask_author(to:, cc:, from:, subject:, body:)
    mail(to: to, cc: cc, from: from, subject: subject) do |format|
      format.text { render plain: body }
    end
  end
end
