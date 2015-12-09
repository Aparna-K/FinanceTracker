####Helpers
module ScraperHelper
  def wait(time = 30.seconds)
    Selenium::WebDriver::Wait.new(:timeout => time.to_i)
  end

  #wait_for_element(:id, "id1")
  def wait_for_element(find_method, identifier, time = 30.seconds)
    wait(time).until{
      @driver.find_elements(find_method, identifier).count > 0 &&
          @driver.find_element(find_method, identifier).enabled? &&
          @driver.find_element(find_method, identifier).displayed?
    }
    @driver.find_element(find_method, identifier)
  end
end
