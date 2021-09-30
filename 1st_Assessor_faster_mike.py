#Practice file for Mike, created on election day, 2020
#added comments for completed to-dos, and comments that start with 'Mike:' for questions
#true file paths are replaced with practice file paths to my folder in the W drive. 
#The actual path is commented on the same line

import os, zipfile
import pandas as pd
import numpy as np
import csv
import datetime
import sys

def column_sort(county): #sort df in following order:
    county = county[['FIPS','PropertyID','APN','APNSeqNbr','OldAPN','SitusFullStreetAddress',           
                      'SitusCity','SitusState','SitusZIP5','SitusLatitude',
                      'SitusLongitude','SitusGeoStatusCode','LandUseCode',
                      'SitusCensusTract','AssdTotalValue','AssdLandValue','AssdImprovementValue',
                      'TaxAmt','TaxYear','TaxDeliquentYear','AssdYear','BuildingArea',
                      'BuildingAreaInd','SumBuildingSqFt','SumLivingAreaSqFt',
                      'SumGrossAreaSqFt','SumAdjAreaSqFt','SumBasementSqFt','SumGarageSqFt',
                      'YearBuilt','EffectiveYearBuilt','Bedrooms','TotalRooms','BathTotalCalc',
                      'BathFull','BathsPartialNbr','LotCode','LandLot','CurrentAVMValue','FATimeStamp',
                      'FARecordType','LotNbr','LotSizeSqFt','Garage','GarageParkingNbr']]
    return county            

if __name__ == "__main__":

    date = sys.argv[1]
    n = int(sys.argv[2]) #read second argument [index] as integar
    
    
    dir_name = 'W:/Mike/py_file/practice/Archive/'+date+'/Annual/' #'X:/Archive/'+date+'/Annual/' #assign file path
    #one of the advantages of complete data refresh is no need to differentiate Update and Annual
    extension = ".zip"
    
    #create folder 'X:/final/DATE/Assessor/
    dir_save0 = 'W:/Mike/py_file/practice/final/'+date+'/' #'X:/final/'+date+'/'
    
    try:
        os.mkdir(dir_save0)
    except FileExistsError:
        print('Path already exists.')
    
    dir_save = 'W:/Mike/py_file/practice/final/'+date+'/Assessor/' #'X:/final/'+date+'/Assessor/'
    try:
        os.mkdir(dir_save)
    except FileExistsError:
        print('Path already exists.')

    usecolumns =['FIPS','PropertyID','APN','APNSeqNbr','OldAPN','SitusFullStreetAddress',              
                 'SitusCity','SitusState','SitusZIP5','SitusLatitude','SitusLongitude',
                 'SitusGeoStatusCode','LandUseCode',
                 'SitusCensusTract','AssdTotalValue','AssdLandValue','AssdImprovementValue',
                 'TaxAmt','TaxYear','TaxDeliquentYear','AssdYear','BuildingArea',
                 'BuildingAreaInd','SumBuildingSqFt','SumLivingAreaSqFt','SumGrossAreaSqFt','SumAdjAreaSqFt',
                 'SumBasementSqFt','SumGarageSqFt','YearBuilt','EffectiveYearBuilt','Bedrooms','TotalRooms',
                 'BathTotalCalc','BathFull','BathsPartialNbr','LotCode',
                 'LandLot','CurrentAVMValue','FATimeStamp',
                 'FARecordType','LotNbr','LotSizeSqFt','Garage','GarageParkingNbr']
     
    datatypes = {'FIPS':str,
             'PropertyID':str,
             'APN':str,
             'APNSeqNbr':str,
             'OldAPN':str,
             'SitusFullStreetAddress':str,
             'SitusCity':str,
             'SitusState':str,
             'SitusZIP5':str,
             'SitusLatitude':str,
             'SitusLongitude':str,
             'SitusGeoStatusCode':str,
             'LandUseCode':str,
             'SitusCensusTract':str,
             'AssdTotalValue':np.float,
             'AssdLandValue':np.float,
             'AssdImprovementValue':np.float,
             'TaxAmt':np.float,
             'TaxYear':str,
             'TaxDeliquentYear':str,
             'AssdYear':str,
             'BuildingArea':np.float,
             'BuildingAreaInd':str,
             'SumBuildingSqFt':np.float,
             'SumLivingAreaSqFt':np.float,
             'SumGrossAreaSqFt':np.float,
             'SumAdjAreaSqFt':np.float,
             'SumBasementSqFt':np.float,
             'SumGarageSqFt':np.float,
             'YearBuilt':str,
             'EffectiveYearBuilt':str,
             'Bedrooms':np.float,
             'TotalRooms':np.float,
             'BathTotalCalc':np.float,
             'BathFull':np.float,
             'BathsPartialNbr':np.float,
             'LotCode':str,
             'LandLot':str,
             'CurrentAVMValue':np.float,
             'FATimeStamp':str,
             'FARecordType':str,
             'LotNbr':str,
             'LotSizeSqFt':np.float,
             'Garage':np.float,
             'GarageParkingNbr':np.float}

    for item in os.listdir(dir_name)[n:]:
        if item.endswith(extension): # check for ".zip" extension
            new_file = dir_name+item #assign file path to the variable here
            #read in zip file in the new_file path using pandas and all necessary arguments.
            county_new = pd.read_csv(new_file, compression='zip', header=0, sep='|',  
                                 usecols= usecolumns,
                                 quoting=csv.QUOTE_NONE,
                                 dtype = datatypes,
                                 keep_default_na = True,
                                 error_bad_lines=False)
            
            county_new = column_sort(county_new)
            county_new.to_csv(dir_save+item[:9]+".csv",index=False) #save single county file
            print(str(n)+" "+item[:9]+ " single file written.")
        
                
                
                #save counties in the master file
            with open("W:/Mike/py_file/practice/final/"+date+"/Assessor_skinny.csv",'a') as wfile: #"X:/final/"+date+"/Assessor_skinny.csv"
                if os.stat("W:/Mike/py_file/practice/final/"+date+"/Assessor_skinny.csv").st_size == 0 : #same as above
                    county_new.to_csv(wfile,index=False)
                else:
                    county_new.to_csv(wfile,index=False,header = False)
                    print(str(n)+" "+item[:9]+" #rows:"+str(len(county_new))) #Mike: is it necessary to print 'n' again?
                        
                n=n+1
                
    print("Done at {}.".format(datetime.datetime.now()))

