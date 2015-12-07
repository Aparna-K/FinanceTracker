require "selenium-webdriver"
require 'pry'
require "yaml"
require 'date'
require 'active_support/all'
require 'csv'
require "google/api_client"
require "google_drive"

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
	def setup_google_drive
		creds = YAML.load_file("#{ENV['HOME']}/.googleapps/config.yml")
		session = GoogleDrive.saved_session("./stored_token.json", nil, creds["CLIENT_ID"], creds["CLIENT_SECRET"])
		session
	end
end


class BofaScraper
	include ScraperHelper

	attr_accessor :driver, :config, :start_date, :google_session, :csv_file

	OUTPUT_HEADERS = ["Date", "Description", "Type", "Status", "Amount", "Available Balance"]

	def initialize(time_range_in_days = 30)
		@driver = Selenium::WebDriver.for :chrome
		@config = YAML.load_file("#{ENV['HOME']}/.bofa/config.yml")
		@start_date = Date.today - time_range_in_days.days
		@google_session = setup_google_drive
		@csv_file = "BofaScrapeOutput#{Date.today.strftime('%Y-%m-%d')}.csv"
	end

	def scrape
		@driver.navigate.to config["BANK_HOME"]
		@driver.find_element(:id, "onlineId1").send_keys config["ID"]
		@driver.find_element(:id, "passcode1").send_keys config["PWD"]
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

	def read_from_csv(csv_file)
		read_file = CSV.read(csv_file)
		read_file.map(&:to_a)
	end

	def update_google_drive
		finances_sheet = @google_session.spreadsheet_by_title("Financials")
		if finances_sheet
			ws = finances_sheet.worksheet_by_title("Financials")
		else
			finances_sheet = @google_session.create_spreadsheet("Financials")
			ws = finances_sheet.add_worksheet("Financials")
			all_rows = read_from_csv @csv_file
			all_rows.each_with_index do |row, i|
			  row.each_with_index do |col, j|
			    ws[i+1, j+1] = col
			  end  
			end  
			ws.save
		end
	end
end

### - Save the transfer id
### - Match up the difference when you update doc