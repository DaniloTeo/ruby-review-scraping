# frozen_string_literal: true

require 'selenium-webdriver'

def print_status(str)
  print "[STATUS] #{str}\n"
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

  print link_list
end

def scrape
  # initialize chrome webdriver with selenium globally
  # initialize explicit wait options
  print_status('Initializing webdriver...')
  initialize_scraper
  # navigate to author's url in website
  @driver.get('https://sequentialplanet.com/author/dteo/')

  # wait until the page's footer is displayed in browser
  @wait.until { @driver.find_element(:css, 'footer.main-footer').displayed? }
  #   print_status('Page accessed...')

  #   begin
  #     print @driver.find_element(:css, 'a.next.page-numbers').displayed?
  #   rescue Selenium::WebDriver::Error::NoSuchElementError => e
  #     print e
  #   end

  print_status('Preparing to navigate pages of review...')
  navigate_pages

  # screen shot to assert we're where we want
  @driver.save_screenshot('./sp.png')
end

# call main function
scrape
