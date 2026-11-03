require "capybara"
require "selenium-webdriver"

# Chrome can report a node from the previous document as UnknownError instead
# of StaleElementReferenceError during navigation. Use Capybara's existing
# reload and timeout rules for this one error, including page-wide queries.
# Upstream: https://github.com/teamcapybara/capybara/issues/2850
module ChromeDetachedNodeRetry
     protected

     def catch_error?(error, errors = nil)
          if error.is_a?(Selenium::WebDriver::Error::UnknownError) &&
               error.message.include?("Node with given id does not belong to the document")
               stale = Selenium::WebDriver::Error::StaleElementReferenceError.new(error.message)
               return super(stale, errors)
          end

          super
     end
end

Capybara::Node::Base.prepend(ChromeDetachedNodeRetry)
