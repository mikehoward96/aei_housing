import pandas as pd
import numpy as np
import csv
from datetime import datetime
import sys
import os
import requests
import json

def pull_all():
    for i in range(len(new_con_wo_yearBuilt)):
         housenumber = new_con_wo_yearBuilt.iloc[i]['HOUSENUMBER']
         streetname = new_con_wo_yearBuilt.iloc[i]['STREETNAME']
         suffix = new_con_wo_yearBuilt.iloc[i]['Suffix']
         unit = new_con_wo_yearBuilt.iloc[i]['UNITNUMBER']
         zipcode = new_con_wo_yearBuilt.iloc[i]['ZIPCODE']
         address = housenumber+' '+streetname+' '+suffix+' '+unit
        
         try:
            zillow_byte = requests.get("https://api.bridgedataoutput.com/api/v2/pub/parcels?access_token="+token+"&fields=building.yearBuilt,landUseCode,landUseDescription&address.full.in="+address+"&address.zip="+zipcode).content
            
            try:    #below: turn byte object into dictionary
                bundle = dict(json.loads(zillow_byte.decode('utf-8')))['bundle'][0]              
                      
                    #extract variables we want
                try:yearBuilt = bundle['building'][0]['yearBuilt']
                except:yearBuilt = None
                    
                try:landUseCode = bundle['landUseCode']
                except:landUseCode = None
                    
                try:landUseDescription = bundle['landUseDescription']
                except:landuseDescription = None

                result_df = pd.DataFrame([[housenumber,streetname,suffix,unit,zipcode,
                                 yearBuilt,landUseCode,landUseDescription]],
                                     columns=['housenumber','streetname','suffix','unitnumber','zipcode',
                                             'yearbuilt','landusecode','landusedescription'])
                
                with open ('W:/Mike/api/new_con_w_zillow.csv','a') as wfile:
                    if os.stat('W:/Mike/api/new_con_w_zillow.csv').st_size == 0:
                        result_df.to_csv(wfile,index=False)
                    else:
                        result_df.to_csv(wfile,index=False,header=False)
                print(i)
                
            except:# there is no record at all ,no 'response'
                print("{} no record".format(i))
                pass
            
           
         except: 
                pass
            
def pull_part(start,end):
    for i in range(start,end):
         housenumber = new_con_wo_yearBuilt.iloc[i]['HOUSENUMBER']
         streetname = new_con_wo_yearBuilt.iloc[i]['STREETNAME']
         suffix = new_con_wo_yearBuilt.iloc[i]['Suffix']
         unit = new_con_wo_yearBuilt.iloc[i]['UNITNUMBER']
         zipcode = new_con_wo_yearBuilt.iloc[i]['ZIPCODE']
         address = housenumber+' '+streetname+' '+suffix+' '+unit
        
         try:
            zillow_byte = requests.get("https://api.bridgedataoutput.com/api/v2/pub/parcels?access_token="+token+"&fields=building.yearBuilt,landUseCode,landUseDescription&address.full.in="+address+"&address.zip="+zipcode).content
            
            try:    #below: turn byte object into dictionary
                bundle = dict(json.loads(zillow_byte.decode('utf-8')))['bundle'][0]              
                      
                    #extract variables we want
                try:yearBuilt = bundle['building'][0]['yearBuilt']
                except:yearBuilt = None
                    
                try:landUseCode = bundle['landUseCode']
                except:landUseCode = None
                    
                try:landUseDescription = bundle['landUseDescription']
                except:landuseDescription = None

                result_df = pd.DataFrame([[housenumber,streetname,suffix,unit,zipcode,
                                 yearBuilt,landUseCode,landUseDescription]],
                                     columns=['housenumber','streetname','suffix','unitnumber','zipcode',
                                             'yearbuilt','landusecode','landusedescription'])
                
                with open ('W:/Mike/api/new_con_w_zillow_'+str(start)+'_'+str(end)+'.csv','a') as wfile:
                    if os.stat('W:/Mike/api/new_con_w_zillow_'+str(start)+'_'+str(end)+'.csv').st_size == 0:
                        result_df.to_csv(wfile,index=False)
                    else:
                        result_df.to_csv(wfile,index=False,header=False)
                print(i)
                
            except:# there is no record at all ,no 'response'
                print("{} no record".format(i))
                pass
            
           
         except: 
                pass

if __name__=='__main__':   
    token = '6005e885410c739c67fe2379ef1b9470' #server token from Bridge API
    path = sys.argv[1]
    start = int(sys.argv[2])
    end = int(sys.argv[3])
    
    ##find the new records to pull
    old = pd.read_csv("W:/Mike/api/new_con_w_zillow.csv",dtype = str)
    if start ==0:
        old.to_csv("W:/Mike/api/backup-new_con_w_zillow.csv",index=False)
        print("backup-new_con_w_zillow.csv is created.")
        
    if path == 'default':
        new = pd.read_stata('X:/tobias/intermed data/new_construction_api_dedup.dta')#W:/Mike/api/testing/new_construction_api_dedup_100.dta
    else: 
        new = pf.read_stata(path)

    new_con_wo_yearBuilt = new.astype(object).replace(np.nan, '') 
    print("The number of rows to pull: "+str(len(new_con_wo_yearBuilt)))
     
    print(datetime.now())

    if end ==0: pull_all()
    else: pull_part(start,end)
    
    print("Done at "+str(datetime.now()))