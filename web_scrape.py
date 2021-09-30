import requests
from bs4 import BeatifulSoup
import csv
import pandas as pd
import lxml
import html5lib

url = "https://en.wikipedia.org/wiki/List_of_mass_shootings_in_the_United_States"
website_html = requests.get(url).text
soup = BeautifulSoup(website_html, 'html.parser')

#print(soup.prettify())

my_table_21_19 = soup.findAll('table', {'class':'wikitable sortable mw-datatable'})
my_table_18_older = soup.findAll('table', {'class':'wikitable sortable'})

df_1 pd.read_html(str(my_table_21_19))
df_2 pd.read_html(str(my_table_18_older))

df = df_1+df_2

base_df = df[0]

for x in range(1, len(df)):
	result = df[x]
	base_df = base_df.append(result)

base_df.to_csv('name.csv')