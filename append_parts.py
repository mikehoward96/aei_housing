import csv
import os
import sys
import pandas as pd

if __name__=='__main__':  
    #name = sys.argv[1]

#if name == "1":
    for item in os.listdir('W:/Mike/api/'):
        if item.startswith('new_con_w_zillow_'):
            file = pd.read_csv('W:/Mike/api/'+item,dtype = str)
            with open('W:/Mike/api/new_con_w_zillow.csv','a') as wfile:
                   file.to_csv(wfile,index=False,header=False)
            print(item)
            os.remove('W:/Mike/api/'+item)