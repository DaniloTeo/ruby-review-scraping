# frozen_string_literal: true

require 'selenium-webdriver'

def print_status(str)
  print "[STATUS] #{str}\n\n"
end

def initialize_scraper
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  @driver = Selenium::WebDriver.for :chrome, options: options
  @wait = Selenium::WebDriver::Wait.new(timeout: 30)
end

def gather_links
  link_list = @driver.find_elements(:css, 'article > a.image-link')
  refs = []
  link_list.each do |link|
    ref = link.attribute('href')
    refs.push(ref)
  end

  refs
end

def navigate_pages
  # driver.action.click(element).perform
  is_last = false
  link_list = []
  page_n = 1
  until is_last
    print_status("Collecting page #{page_n} links...")
    pages_link = gather_links
    link_list.push(pages_link)
    unless is_last
      page_n += 1
      next_page = @driver.find_element(:css, 'a.next.page-numbers').attribute('href')
      @driver.get(next_page)
      @wait.until { @driver.find_element(:css, 'footer.main-footer').displayed? }
    end

    begin
      is_last = !@driver.find_element(:css, 'a.next.page-numbers').displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      is_last = true
    end
  end

  link_list
end

def linearize(matrix)
  linearized_list = []
  matrix.each do |list|
    list.each do |link|
      linearized_list.push(link)
    end
  end
  linearized_list
end

def gather_paragraphs(body)
  ps = []
  body.each do |par|
    ps.push(par.text)
  end
  ps
end

def clean_writers(writers)
  if writers.scan(/&|,/) != []
    writers.slice! 'Writers: '
  else
    writers.slice! 'Writer: '
  end

  writers
end

def clean_artists(artists)
  artists.slice! 'Art: '
  artists
end

def month_to_number(month_name)
  month_number = ''
  case month_name
  when 'JANUARY'
    month_number = '01'
  when 'FEBRUARY'
    month_number = '02'
  when 'MARCH'
    month_number = '03'
  when 'APRIL'
    month_number = '04'
  when 'MAY'
    month_number = '05'
  when 'JUNE'
    month_number = '06'
  when 'JULY'
    month_number = '07'
  when 'AUGUST'
    month_number = '08'
  when 'SEPTEMBER'
    month_number = '09'
  when 'OCTOBER'
    month_number = '10'
  when 'NOVEMBER'
    month_number = '11'
  when 'DECEMBER'
    month_number = '12'

  end
  month_number
end

def clean_timestamp(timestamp)
  day = timestamp.scan(/\w ([0-9]{1,2})/)[0][0]
  day = "0#{day}" if day.length < 2
  month = month_to_number(timestamp.scan(/[A-Z]+/)[0])
  year = timestamp.scan(/, ([0-9]{4})/)[0][0]
  "#{year}-#{month}-#{day}"
end

def clean_body(paragraphs)
  body = ''
  paragraphs.each do |par|
    body += "#{par}\n" unless par == ''
  end
  body
end

def review?(cat)
  cat.scan(/REVIEWS/) != []
end

def gather_review_data(review_link)
  print_status("Gathering data from #{review_link}...")
  @driver.get(review_link)
  @wait.until { @driver.find_element(:css, 'footer.main-footer').displayed? }
  cat = @driver.find_element(:css, 'span.cats > a').text
  return unless review?(cat)

  header_list = @driver.find_elements(:css, 'h2')
  title_issue = header_list[0].text
  publisher = header_list[1].text
  writers = header_list[2].text
  artists = header_list[3].text

  timestamp = @driver.find_element(:css, 'time.value-title').text

  body = @driver.find_elements(:css, 'div.post-content > p')
  paragraphs = gather_paragraphs(body)

  begin
    score = @driver.find_element(:css, 'div.overall > span > span').text
  rescue Selenium::WebDriver::Error::NoSuchElementError
    score = nil
  end
  score_number = nil
  score_number = score.to_f unless score.nil?
  #   .cats > a:nth-child(1)
  {
    title: title_issue,
    publisher: publisher,
    writers: clean_writers(writers),
    artists: clean_artists(artists),
    date: clean_timestamp(timestamp),
    body: clean_body(paragraphs),
    score: score_number
  }
end

def gather_reviews(links)
  reviews = []
  links.each do |l|
    review = gather_review_data(l)
    reviews.push(review)
  end
  reviews
end

def scrape(author)
  # initialize chrome webdriver with selenium globally
  # initialize explicit wait options
  print_status('Initializing webdriver...')
  initialize_scraper
  # navigate to author's url in website
  @driver.get("https://sequentialplanet.com/author/#{author}/")

  # wait until the page's footer is displayed in browser
  @wait.until { @driver.find_element(:css, 'footer.main-footer').displayed? }
  print_status('Page accessed...')

  print_status('Preparing to navigate pages of review...')
  link_matrix = navigate_pages

  links = linearize(link_matrix)
  print_status('Visiting reviews and gathering review...')

  reviews = gather_reviews(links)

  File.write('./review.json', JSON.dump(reviews))
end

# call main function
print "Enter author's slug: "
author = gets.chomp
scrape(author)
