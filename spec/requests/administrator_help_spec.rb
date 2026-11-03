require "rails_helper"

RSpec.describe "Embedded administrator instructions", type: :request do
     it "provides the same administrator guide and an offline PDF through Help" do
          sign_in(users(:chief))
          get help_path
          expect(response.parsed_body.at_css("a[href='#{help_path(guide: 'admin')}']")).to be_present
          get help_path(guide: "admin")
          expect(response.body).to include("Database backup and restore", "Administrator training and offline instructions", "Handover evidence")
          expect(response.parsed_body.at_css("a[href='#{restart_guide_path}']")).to be_present
          get restart_guide_path
          expect(response.media_type).to eq("application/pdf")
          expect(response.headers["Content-Disposition"]).to include("attachment", "RESTART_GUIDE.pdf")
          expect(response.body).to start_with("%PDF")
     end

     it "requires chief access for the administrator guide and PDF, while retaining public user help" do
          [ help_path(guide: "admin"), restart_guide_path ].each do |path|
               get path
               expect(response).to redirect_to(login_path)
          end
          [ users(:member), users(:officer) ].each do |person|
               sign_in(person)
               get help_path
               expect(response.body).not_to include("Download restart PDF")
               [ help_path(guide: "admin"), restart_guide_path ].each do |path|
                    get path
                    expect(response).to redirect_to(root_path)
                    expect(flash[:alert]).to include("administrator guide")
               end
          end
     end
end
