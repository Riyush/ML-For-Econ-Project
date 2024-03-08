from Scraping_Functions import *
import pandas as pd

TRANSCRIPT_BASE_LINK = "https://www.fool.com"

#MODIFY THIS LINE to use the scraper
transcript_directory = "/Volumes/My Passport for Mac/Courses/ML For Econ/Project/Custom_Motley_Scraper/Trancripts/"
# Read the Excel file into a pandas DataFrame
df = pd.read_excel('companies_copy.xlsx')

# Convert the DataFrame to a list of lists
list_of_lists = df.values.tolist()

# Iterate through each company
for entry in list_of_lists:
    
    company_name = entry[0]  # First column value
    ticker = entry[1].lower()
    exchange = entry[2].lower()

    #Create the Local Directory with the company name
    create_company_directory(transcript_directory, company_name)

    #Creaet the motley fool url 
    base_company_url = get_base_company_url(ticker, exchange)

    # Enter the url and manually press the "View More Transcripts" button and 
    # Get the page source. Now we have a page with a list of links to 
    # 5 years worth of transcripts
    updated_html_content = get_page_source(base_company_url)

    #Get a dictionary of index = transcript_name, value = transcript link
    transcript_dict = get_transcripts_links(updated_html_content, TRANSCRIPT_BASE_LINK)

    # Access each transcript and convert it to a txt file and place it
    for transcript_name, transcript_url in transcript_dict.items():
        url_to_text_file(transcript_name, transcript_directory, transcript_url, company_name)






