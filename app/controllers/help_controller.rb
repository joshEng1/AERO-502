# Shows docs/USER_GUIDE.md inside the website, so the guide in the repository
# and the one members read are always the same. Open to everyone, so people who
# cannot sign in can still read what to do.
class HelpController < ApplicationController
     GUIDE_PATH = Rails.root.join("docs/USER_GUIDE.md")
     ADMIN_GUIDE_PATH = Rails.root.join("docs/ADMIN_GUIDE.md")
     before_action :require_sign_in, if: :administrator_guide?
     before_action :ensure_administrator, if: :administrator_guide?

     def show
          renderer = Redcarpet::Render::HTML.new(with_toc_data: true, escape_html: true)
          @administrator_guide = administrator_guide?
          path = @administrator_guide ? ADMIN_GUIDE_PATH : GUIDE_PATH
          @guide_html = Redcarpet::Markdown.new(renderer, tables: true, autolink: true).render(path.read)
     end

     def restart
          send_file Rails.root.join("docs/RESTART_GUIDE.pdf"), type: "application/pdf", disposition: "attachment"
     end

     private

     def administrator_guide?
          params[:guide] == "admin" || action_name == "restart"
     end

     def ensure_administrator
          deny_access("Access denied. The administrator guide is available to the Chief Engineer.") unless current_user.chief_engineer?
     end
end
