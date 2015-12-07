require "google/api_client"
require "google_drive"
require 'pry'
# The client ID and client secret you obtained in the step above.
creds = YAML.load_file("#{ENV['HOME']}/.googleapps/config.yml")
CLIENT_ID = creds["CLIENT_ID"]
CLIENT_SECRET = creds["CLIENT_SECRET"]

session = GoogleDrive.saved_session("./stored_token.json", nil, CLIENT_ID, CLIENT_SECRET)


# Uploads a local file.
sheet = session.upload_from_file("BofaScrapeOutput#{Date.today.strftime('%Y-%m-%d')}.csv", "Financials", convert: true)

sheet_id = sheet.id #save this somewhere
File.open("#{ENV['HOME']}/.googleapps/google_sheet_id", "w"){|file| file.write(sheet_id)}

ws = sheet.worksheets[0]
ws.title = "Financials"
ws.save
