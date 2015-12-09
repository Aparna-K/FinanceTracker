require_relative "../scripts/base_finance_scraper"

class BofaScraper < BaseFinanceScraper
  attr_accessor  :csv_file, :bank_config

  def initialize(time_range_in_days = 30)
    @bank_config = YAML.load_file("#{ENV['HOME']}/.bofa/config.yml")
  end

	def scrape
		@driver.get bank_config["BANK_HOME"]
		@driver.find_element(:id, "onlineId1").send_keys bank_config["ID"]
		@driver.find_element(:id, "passcode1").send_keys bank_config["PWD"]
		@driver.find_element(:id, "saveMyID1").click
		@driver.find_element(:id, "hp-sign-in-btn").click
		answer_security_questions
		
		wait_for_element(:name, "DDA_details").click

		data_dump = []
		data_dump = traverse_through_rows
		while !(data_dump.last.split[0].to_date < @start_date)
			@driver.get @driver.find_element(:name, "prev_trans_nav_bottom").attribute("href")
			data_dump.push(traverse_through_rows)
			data_dump = data_dump.flatten
		end
		
		data_dump.reject!{|v| v.split[0].to_date < @start_date if !v.split[0] == "Processing"}
		write_to_csv(data_dump)
		@driver.quit
		update_google_drive
	end

	def traverse_through_rows
		wait.until{ @driver.find_elements(:css, 'table[class = "transaction-records"]  > tbody > tr').count > 0 }
		all_rows = @driver.find_elements(:css, 'table[class = "transaction-records"] > tbody > tr')
		all_rows.delete_if do |v|
			date_val = v.text.split[0]
		  begin
		    date_val.to_date
		    false
		  rescue  
		    if date_val != "Processing"
		      true
		    else  
		      false
		    end  
		  end  
		end
		all_rows.map{
			|el| el.find_elements(:tag_name, "td").map{|td| td.text.blank? ? td.attribute("title") : td.text}.join("\n") 
		}  
	end

	def answer_security_questions
		sleep 5
		if @driver.find_elements(:css, "#VerifyCompForm > div.answer-section > label").size > 0
			security_answer = ""
			loop do
				puts @driver.find_element(:css, "#VerifyCompForm > div.answer-section > label").text
				security_answer = gets.strip
				puts "Is the answer \"#{security_answer}\" correct? (y/n)"
				confirmation = gets.strip.downcase
				if !["y", "n"].include?(confirmation)
					puts "What??"
					next
				else
					confirmation == "y" ? break : next		
				end
			end
			@driver.find_element(:id, "tlpvt-challenge-answer").send_keys security_answer
			@driver.find_element(:id, "verify-cq-submit").click
			wait_for_element(:name, "onh_profile_and_settings").click
			wait_for_element(:name, 'challenge_question').click
			wait_for_element(:name, "cancel-questions-submit").click
			wait_for_element(:id, "tlpvt-recognize").click
			@driver.find_element(:name, "change-security-preference").click
			wait_for_element(:name, "onh_accounts").click
		end
  end

	def write_to_csv(data_dump)
		CSV.open(@csv_file, "wb") do |csv|
			csv << OUTPUT_HEADERS
			data_dump.each do |v|
				csv << v.split("\n")
			end
		end
	end
end

### - Save the transfer id
### - Match up the difference when you update doc