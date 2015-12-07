require "selenium-webdriver"
require 'pry'

checking_last_four_digits = ARGV[0]
credit_last_four_digits = ARGV[1]
user_name = ARGV[2]
pwd = ARGV[3]

last_month = Date.today.month - 1
START_DATE = Date.today.strftime("#{last_month}/27/%Y")
END_DATE = Date.today.strftime('%m/%d/%Y')

driver = Selenium::WebDriver.for :chrome

driver.navigate.to "https://www.bankofamerica.com/homepage/overview.go?page_msg=signoff&request_locale=en_us"

driver.find_element(:xpath, '//*[@id="onlineId1"]').send_keys(user_name)
driver.find_element(:xpath, '//*[@id="passcode1"]').send_keys(pwd)

driver.find_element(:xpath, '//*[@id="hp-sign-in-btn"]').click

sleep 5
driver.find_element(:xpath, "//*[@id='BofA Core Checking - #{checking_last_four_digits}']").click

sleep 5

driver.find_element(:xpath, '//*[@id="depositDownLink"]/a').click

driver.find_element(:xpath, '//*[@id="cust-date"]').click

driver.find_element(:xpath, '//*[@id="start-date"]').send_keys(START_DATE)

driver.find_element(:xpath, '//*[@id="end-date"]').send_keys(END_DATE)

driver.find_element(:name, 'download_file_in_this_format_CSV').click

driver.find_element(:xpath, '//*[@id="icon-legend-download"]/div/form/div[4]/div[2]/a/span').click

#go back to home page

driver.find_element(:name, 'onh_accounts').click

sleep 5
driver.find_elements(:xpath, "//*[contains(@id, '#{credit_last_four_digits}')]")[0].click

sleep 3
driver.find_element(:name, 'download_transactions_top').click

driver.find_element(:name, 'download_file_in_this_format_COMMA_DELIMITED').click

driver.find_element(:class, 'submit-download').click
