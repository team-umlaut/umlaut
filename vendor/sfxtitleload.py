#!/usr/bin/python
import re
title_files = ["../tmp/git.txt", "../tmp/gal.txt"]
title_list = ""
for file in title_files:
    f = open(file)
    title_list += f.read()
    f.close()
f = open(stat_file)
stat_list = f.read()
f.close()
lines = title_list.split("\n")
stat_lines = stat_list.split("\n")
data = []
stats = {}
for line in lines:
    data.append(line.split("\t"))
for sline in stat_lines:
    l = sline.split("\t")
    issn = l[0].split(" ")[0]
    if issn and len(l) == 3:    
        stats[issn] = l[2]
        
import MySQLdb

db = MySQLdb.connect(host="localhost", user="root", passwd="s3m1nary", db="resolver" )   

dbc = db.cursor()
dbc.execute("TRUNCATE TABLE journals")
dbc.execute("TRUNCATE TABLE journal_titles")
dbc.execute("TRUNCATE TABLE categories")
dbc.execute("TRUNCATE TABLE categories_journals")
dbc.execute("TRUNCATE TABLE journal_categories")
dbc.execute("TRUNCATE TABLE coverages")
object_ids = {}
categories = {}

for d in data:
    try:
        cats = []
        if d[4] not in object_ids.keys():   
          norm = re.sub('^(the|an?)\s', '', d[1].lower())
          pg = "0"
          if re.match("^[a-z]", norm[0]):
            pg = norm[0]
            
          dbc.execute("INSERT INTO journals (object_id, title, normalized_title, page, issn, eissn, title_source_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)", (d[4], d[1], norm, page, d[3], d[7], 1))
          id = dbc.lastrowid
          object_ids[d[4]] = id
        else:
          id = object_ids[d[4]]
            
        if(d[1] != ""):
          dbc.execute("INSERT INTO coverage (journal_id, provider, coverage) VALUES (%s, %s, %s)", (id, d[5], d[6]))
          title = d[1]
          dbc.execute("INSERT INTO journal_titles (title, journal_id) VALUES (%s, %s)", (d[1], id))

        alt_titles = d[8].split("-")
        for a in alt_titles:
            if a != "":
              dbc.execute("INSERT INTO journal_titles (title, journal_id) VALUES (%s, %s)", (a, id)        
        
        #print d[21]
        if(d[21] != ""):
          for cat_subcat in d[21].split(' | '):
            if cat_subcat not in categories.keys():
              print cat_subcat
              category, subcat = cat_subcat.split(' - ')                                
              dbc.execute("INSERT INTO categories (category, subcategory) VALUES (%s,%s)", (category,subcat))
              cat_id = dbc.lastrowid
            else:
              cat_id = categories[cat_subcat]
              
            dbc.execute("INSERT INTO journal_categories (journal_id, category_id) VALUES (%s, %s)", (id, cat_id))            
    except (IndexError, MySQLdb.IntegrityError):
        print "\t".join(d)+"\n"
        
