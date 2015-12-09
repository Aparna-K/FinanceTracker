require "selenium-webdriver"
require 'pry'
require "yaml"
require 'date'
require 'active_support/all'
require 'csv'
require "google/api_client"
require "google_drive"
require_relative "../scripts/scraper_helper"

OUTPUT_HEADERS = ["Date", "Description", "Type", "Status", "Amount", "Available Balance"]

class BaseFinanceScraper
  include ScraperHelper
  attr_accessor :driver, :start_date, :google_session

  def initialize(time_range_in_days = 30)
    @driver = Selenium::WebDriver.for :chrome
    @start_date = Date.today - time_range_in_days.days
    @google_session = setup_google_drive
    @csv_file = "BankScrapeOutput#{Date.today.strftime('%Y-%m-%d')}.csv"
  end

  def scrape
    raise "Reimplement this!"
  end

  # ~/.googleapps/config.yml
  #-------------------------
  # CLIENT_ID:
  #     "client_d"
  # CLIENT_SECRET:
  #     "client_secret"

  def setup_google_drive
    creds = YAML.load_file("#{ENV['HOME']}/.googleapps/config.yml")
    session = GoogleDrive.saved_session("./stored_token.json", nil, creds["CLIENT_ID"], creds["CLIENT_SECRET"])
    session
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