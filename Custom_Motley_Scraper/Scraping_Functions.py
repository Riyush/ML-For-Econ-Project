from bs4 import BeautifulSoup
import requests
from selenium import webdriver
from selenium.webdriver.support.select import By
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains
import time
import os



def get_base_company_url(ticker, exchange):
    """
    This function returns the url for a company's page on Motley Fool.
    The company url must be identified by company ticker and exchange.

    Arguments:
    
    ticker [str]: company ticker symbol
    exchange [str]: the exchange the company is traded on 
    
    Returns: 

    base_company_url [str]: The final url of the company on Motley Fool
    """
    base_company_url = f"https://www.fool.com/quote/{exchange}/{ticker}/#quote-earnings-transcripts"
    return base_company_url

def get_page_source(base_company_url):
    """
    This function uses a selenium driver to programatically open the base_company_url,
    escape the predicted popup, click the "View More Transcripts" button until all
    transcripts are loaded. With all transcripts loaded, we then store the 
    loaded html page source to be parsed.

    Arguments:

    base_company_url [str]: The original url of the company we need to modify

    Returns:

    updated_html_content [unclear]: The html code of the page we ultimately want to parse.
    """
    # Open the page for the company on Motley Fool
    driver = webdriver.Chrome()
    driver.get(base_company_url)
    print("Sanity Check")
    time.sleep(5)
    try: 
        #Wait for the popup to appear (adjust timeout as needed)
        time.sleep(8)
        popup_element = WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.XPATH, "//*[@id='popup-x']")))
        popup_element.click()
        print("Ad popup detected and closed.")
    except:
        # If the ad popup doesn't appear, continue execution as normal
        print("No ad popup detected. Continuing execution.")

    #create ActionChains object to scroll to the button so it can be properly clicked
    actions = ActionChains(driver)

    try: 
        # Find the view more Transcripts button using its Xpath selector
        button_element = driver.find_element(By.XPATH, "//*[@id='quote-earnings-transcripts']/button[1]")

        # Click the button until, all transcripts are loaded
        while button_element.is_displayed():
            print("Finding Button")
            actions.move_to_element(button_element).perform()
            # Scroll down a bit more using JavaScript
            driver.execute_script("window.scrollBy(0, 100);")  # Adjust the value as needed
            time.sleep(3)
            button_element.click()
            print("Clicked Button")
            time.sleep(3)
    except NoSuchElementException:
        print("Button element not found. Skipping transcript loading.")
    # Extract the updated HTML content from the browser
    updated_html_content = driver.page_source
    # Close the WebDriver
    driver.quit()

    return updated_html_content

def get_transcripts_links(updated_html_content, TRANSCRIPT_BASE_LINK):
    """
    This function takes html_content and creates a dictionary of links
    to all the transcripts.

    Arguments: 

    updated_html_content [unclear]: the html content to be parsed
    TRANSCRIPT_BASE_LINK: Universal base link for trasncripts on Motley Fool

    Returns:

    transcripts: dictionary of links to all transcripts.
    """
    #Create a BeautifulSoup object and parse the response for transcript links
    soup = BeautifulSoup(updated_html_content, features = "lxml")

    # Next, we get a list of divs with all links. These divs have class = 'page'
    # Isolate all the divs with class "page" 
    transcript_container_div = soup.find('div', id='earnings-transcript-container')
    page_divs = transcript_container_div.find_all('div', class_='page')

    transcripts = {}

    # Iterate over each page and grab the 4 urls of each page
    for page_div in page_divs:
        a_tags = page_div.find_all('a',attrs={'data-track-link': True, 'href': True})
        for a_tag in a_tags:
            transcript_title = a_tag['data-track-link']
            transcript_url_excess = a_tag['href']
            final_link = f"{TRANSCRIPT_BASE_LINK}{transcript_url_excess}"

            transcripts[transcript_title] = final_link

    return transcripts

def url_to_text_file(transcript_name, base_transcript_directory, transcript_url, Company_name):
    """
    This function takes ONE URL and converts the transcript text 
    into a .txt file with the name of the company and specific
    information about a trancript call

    Arguments: 

    trancript_name [str]: The index of the trancript dictionary returned
    from the previous function. Used to name the .txt file.

    base_transcript_directory [str]: base path of directory where I want to put all transcripts
    trancript_url [str]: The url to be converted into a .txt file. 

    Company_name: Name of the company to eventually save the transcript in the right folder.
    """

    transcript_content = requests.get(transcript_url)

    soup = BeautifulSoup(transcript_content.content, 'html.parser')

    try:

        # Find the <div> element with class "article-pitch-container"
        div_container = soup.find('div', class_='article-body')

        # Remove the ad 
        div_container.find('div', class_="article-pitch-container").decompose()
    except:
        print("no ad found")

    # Find all <p> tags within the <div> element
    paragraphs = div_container.find_all('p')

    transcript_string = ""
    
    for p in paragraphs:
        transcript_string += p.get_text() + '\n'

    #Specify file Path, MAKE SURE the folder is created
    file_path = f"{base_transcript_directory}{Company_name}/{transcript_name}.txt"

    # Write the transcript text to the file
    with open(file_path, 'w') as file:
        file.write(transcript_string)

    print(f"Transcript has been saved as: {transcript_name}")

def create_company_directory(transcripts_directory, company_name):
    """
    This function creates a local directory named Company_name in the 
    specified transcript directory to hold all generated transcripts.
    
    Arguments:

    Company_name [str]: Name of the company and the created directory

    transcripts_directory [str]: Name of the directory where the company directory
    will be created.

    Returns: void
    """  
    # Construct the full path for the new directory
    company_directory_path = os.path.join(transcripts_directory, company_name)

    try:
        # Create the directory
        os.mkdir(company_directory_path)
        print(f"Directory '{company_name}' created successfully in '{transcripts_directory}'.")
    except FileExistsError:
        # Directory already exists
        print(f"Directory '{company_name}' already exists in '{transcripts_directory}'.")
