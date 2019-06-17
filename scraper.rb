require 'scraperwiki'
require 'mechanize'

# Scraping from Masterview 2.0

def scrape_page(page)
  page.at("table.rgMasterTable").search("tr.rgRow,tr.rgAltRow").each do |tr|
    tds = tr.search('td').map{|t| t.inner_html.gsub("\r\n", "").strip}
    day, month, year = tds[2].split("/").map{|s| s.to_i}
    record = {
      "info_url" => (page.uri + tr.search('td').at('a')["href"]).to_s,
      "council_reference" => tds[1],
      "date_received" => Date.new(year, month, day).to_s,
      "description" => tds[3].gsub("&amp;", "&").split("<br>")[1].squeeze(" ").strip,
      "address" => tds[3].gsub("&amp;", "&").split("<br>")[0].gsub("\r", " ").squeeze(" ").strip,
      "date_scraped" => Date.today.to_s
    }
    #p record
    puts "Saving record " + record['council_reference'] + ", " + record['address']
    ScraperWiki.save_sqlite(['council_reference'], record)
  end
end

# Implement a click on a link that understands stupid asp.net doPostBack
def click(page, doc)
  href = doc["href"]
  if href =~ /javascript:__doPostBack\(\'(.*)\',\'(.*)'\)/
    event_target = $1
    event_argument = $2
    form = page.form_with(id: "aspnetForm")
    form["__EVENTTARGET"] = event_target
    form["__EVENTARGUMENT"] = event_argument
    form.submit
  else
    # TODO Just follow the link likes it's a normal link
    raise
  end
end

url = "http://pdonline.ipswich.qld.gov.au/pdonline/modules/applicationmaster/default.aspx"

agent = Mechanize.new

# Read in a page
page = agent.get(url)

form = page.forms.first
button = form.button_with(value: "I Agree")
form.submit(button)

((Date.today - 14)..(Date.today)).each do |date|
  query_period = "?page=found&5=T&6=F&1=" + date.strftime("%d/%m/%Y") + "&2=" + date.strftime("%d/%m/%Y")

  puts "Date: " + date.to_s

  page = agent.get(url + query_period)
  current_page_no = 1
  next_page_link = true

  while next_page_link
    puts "Scraping page #{current_page_no}..."
    scrape_page(page)

    page_links = page.at(".rgNumPart")
    if page_links
      next_page_link = page_links.search("a").find{|a| a.inner_text == (current_page_no + 1).to_s}
    else
      next_page_link = nil
    end
    if next_page_link
      current_page_no += 1
      page = click(page, next_page_link)
    end
  end
end
