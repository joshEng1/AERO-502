require "rails_helper"

RSpec.describe ChromeDetachedNodeRetry do
     let(:browser_session) { Capybara::Session.new(:selenium_chrome_headless) }
     let(:node) { Capybara::Node::Base.new(browser_session, nil) }
     let(:message) do
          'unknown error: unhandled inspector error: {"code":-32000,"message":"Node with given id does not belong to the document"}'
     end
     let(:detached_error) { Selenium::WebDriver::Error::UnknownError.new(message) }

     it "reloads and retries a detached node within the normal wait" do
          attempts = 0
          expect(node).to receive(:reload).once.and_call_original

          result = node.synchronize(1) do
               attempts += 1
               raise detached_error if attempts == 1
               :replacement_document
          end

          expect(result).to eq(:replacement_document)
          expect(attempts).to eq(2)
          expect(browser_session.synchronized).to be(false)
     end

     it "still raises the original error when the wait expires" do
          expect(node).not_to receive(:reload)
          expect { node.synchronize(0) { raise detached_error } }.to raise_error do |error|
               expect(error).to equal(detached_error)
          end
          expect(browser_session.synchronized).to be(false)
     end

     it "does not retry unrelated Selenium errors" do
          error = Selenium::WebDriver::Error::UnknownError.new("disconnected: not connected to DevTools")
          expect(node).not_to receive(:reload)
          expect { node.synchronize(1) { raise error } }.to raise_error do |raised|
               expect(raised).to equal(error)
          end
     end

     it "does not retry application errors with the same text" do
          error = RuntimeError.new(message)
          expect(node).not_to receive(:reload)
          expect { node.synchronize(1) { raise error } }.to raise_error do |raised|
               expect(raised).to equal(error)
          end
     end

     it "honors a caller that excludes stale-element retries" do
          expect(node).not_to receive(:reload)
          expect { node.synchronize(1, errors: []) { raise detached_error } }.to raise_error do |error|
               expect(error).to equal(detached_error)
          end
     end

     it "leaves ordinary stale-element recovery working" do
          attempts = 0
          error = Selenium::WebDriver::Error::StaleElementReferenceError.new("stale element reference")
          result = node.synchronize(1) do
               attempts += 1
               raise error if attempts == 1
               :replacement_document
          end

          expect(result).to eq(:replacement_document)
          expect(attempts).to eq(2)
     end
end
