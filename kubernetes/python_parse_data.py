import csv
import pymysql 
import datetime

#Load text file into list with CSV module
with open('airlines.dat', 'rt') as f:
	reader = csv.reader(f, delimiter = ',', skipinitialspace=True)
	lineData = list()
	cols = next(reader)

	for line in reader:
		if line != []:
			lineData.append(line)


#Connect with database
cnx = pymysql.connect(user = '', password = '',
						  host = '',
						  database = 'first')
cursor = cnx.cursor()

sqlQuery = "CREATE TABLE quantum(a int, b varchar(200), c varchar(200), d varchar(200), e varchar(200), f varchar(200), g varchar(200), h varchar(200))"   
cursor.execute(sqlQuery)

 

#Writing Query to insert data
query = ("INSERT INTO quantum "
		 "(a, b, c, d, e, f, g, h)"
		 "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)")

#Change every item in the sub list into the correct data type and store it in a directory
for i in range(len(lineData)):
	quantum = (lineData[i][0], lineData[i][1], lineData[i][2],lineData[i][3],lineData[i][4],lineData[i][5],lineData[i][6],lineData[i][7])

 
	cursor.execute(query, quantum) #Execute the Query

#Commit the query
cnx.commit()
cnx.close()
