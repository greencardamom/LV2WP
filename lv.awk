#!/bin/awk -f 

#################################################################
# LV2WP
# lv2wp.awk
# Adapted from PG2WP
# (Gawk 4+)
#
# Naming conventions: lowercase                 = Local variable eg. "str[i]" (arrays and numbers)
#                     Capital first letter      = Global variable eg. Stamp (defined in init.awk)
#                     Cap first and last letter = Global array eg. DaB or WorkS or PG
#                     Cap last letter           = Local array with associative index eg. localS["files"]
#                     ALL CAPS                  = Static defined in init.awk eg. PG_HOME or WGET
#                                                 Also, Awk's own internal variables eg. ARGV, RS, FS etc
#
# Copyright (c) User:Green Cardamom (on en.wikipeda.org)
# February 2015
# License: MIT (see LICENSE file included with this package)
#################################################################

@include "getopt.awk"     # from /usr/share/awk
@include "init.awk"       # custom paths and static
@include "library.awk"    # standard functions

BEGIN {

  # If an option conflicts with Awk's own, need to run with a "--" eg. pg.awk -- -f filename 

  while ((c = getopt(ARGC, ARGV, "z:k:j:")) != -1) {
    opts++
    if(c == "j") {
      datafile = PG_HOME Optarg
      if(! exists(datafile)) {
        printf("File does not exist: %s\n",datafile)
        exit 1
      }
    }
    if(c == "k") 
      outfile = PG_HOME Optarg

    if(c == "z")
      PG_LOG = PG_HOME Optarg
  }

  if(opts == 0) 
    usage()

  if(outfile == "" || datafile == "")
    usage()

  Debug = 1 # On all the time by default, recommended though not required.

  t = strftime("%Y-%m-%d %H:%M:%S") 
  print t >> PG_LOG


 # See 0README step 4. for how to create "match" files from previous runs of PG2WP so work is not repeated in future runs.
  Foundfilename = PG_HOME "match-found"
  if(exists(Foundfilename)) 
    Found = 1
  else
    Found = ""
  Fpfilename = PG_HOME "match-false-positive"
  if(exists(Fpfilename)) 
    FalsePositives = 1
  else
    FalsePositives = ""
  Posfilename = PG_HOME "match-possible"
  if(exists(Posfilename)) 
    Possibles = 1
  else
    Possibles = ""

  main(datafile)

  t = strftime("%Y-%m-%d %H:%M:%S") 
  print t >> PG_LOG

  stats()

}  

function main(datafile	,rawname,rawstr,str,wikipage,article,findtype,type,a,b,d,di,ld,wpdates,pgdates,numofbooks)
{

 # Read in one name
  while ((getline rawname < datafile ) > 0) {

    split(rawname,str,"|")         # See convert.awk

    if(str[3] != "Unknown" || str[2] == "Various" || str[4] ~ "span class") { 
      print rawname >> outfile
      close(outfile)
      continue
    }

    sleep(2)

   # Initialize globals 
    delete DaB                # Empty array of articles found on a Wiki dab page
    delete FlaG		      # Empty array of global boolean flags
    delete WlH		      # Empty array of "What links here" links
    get_pg_date(str[4])       # Fill variables PG["birth"], PG{"deat'h"] and FlaG["fuzzydate"] 
    PG["name"]  = str[2]      # Name created by lv.csh - a best-guess starting point. Static doesn't change.
    PG["ename"] = encode(PG["name"])  # URL-encoded name. Dynamic, may change after redirects, searches etc
    PG["uname"] = PG["name"]  # URL-decoded name. Dynamic, will change along with ename.
    PG["fullname"] = str[2]   # Name created by lv.csh - static
    WP["name"]  = UNK         # What we are trying to find. UNK = "NA" (ie. no name found)
    WP["birth"] = ""
    WP["death"] = ""
    WP["findtype"] = ""       # Debug info on how the program determined the match
    WP["template"] = ""       # If article has {{Gutenberg author}} template (1 or 0)
    FlaG["redirect"] = "No"   # Denote a Wikipedia #redirect page
    FlaG["search"] = "No"     # Denote a Wikipedia Special:Search page
    FlaG["dab"] = "No"        # Denote a Wikipedia disambiguation page
    FlaG["hatnote"] = "No"    # Denote a Wikipedia hatnote dab(s) link(s) 
    FlaG["explang"] = "No"    # Denote a Wikipedia hatnote {{Expand language}}
    FlaG["log"] = "No"        # Only 1 log-entry during dab page scans

    if(Debug) {
      printf("____________________________________________________________________________\n")
      printf("%s\n",PG["name"]) 
      printf("¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\n")
    }
      
    if(PG["name"] != "") {

     # Get the initial WP page
      wikipage = wget_str("http://en.wikipedia.org/wiki/" PG["ename"], PG_TEMP PG["ename"])
      if( match(tolower(wikipage),"[Pp]ool queue is full") ) { # Wikipedia Fast-CGI bug. Try again.
        print "Warning: Pool queue is full, trying again: " PG["fullname"] > "/dev/stderr"
        wikipage = wget_str("http://en.wikipedia.org/wiki/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) {
          print "Error: Pool queue is full, aborting: " PG["fullname"] > "/dev/stderr"
          continue
        }
      }
      findtype = "via dates"

     # WP will sometimes return nothing if the page is not found, when using command line (different in a browser)
     # Force a Special:Search
      if(wikipage == 0) {          
        if(Debug) 
          print "  ----------------------- search (0) -------------------"
        wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
          wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        findtype = "via search"
      }

      type = wiki_pagetype(wikipage)

     # ..But sometimes returns something if nothing is found
      if(type == "dead" || type == "exact"){         
        if(Debug) 
          print "  ----------------------- search (" type ") -------------------"
        wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
          wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        findtype = "via dead"
        type = "search"
        FlaG["search"] = "Yes"
      }

     # Landed on a search page .. get URL-encoded/decoded names of first search result
      if(type == "search") {
         delete a
         match(wikipage, "mw-search-result-heading\x27><a href=\"[^\"]*\" title=\"[^\"]*\"", a)  # match first hit only. To check them all, replace with patsplit()
           # That is: a quote (\") followed by any number (*) of non-quotes ([^\"]) followed by a quote (\").
         split(a[0],b,"\"") 
         gsub("&#039;","'",b[4])
         split(b[2],d,"/")  

         if(length(d[3]) > 0) { # First article in search results
           if(Debug) 
             print "  ----------------------- search (search) -------------------"
           wikipage = wget_str("http://en.wikipedia.org/wiki/" d[3], PG_TEMP d[3])               
           if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
             wikipage = wget_str("http://en.wikipedia.org/wiki/" d[3], PG_TEMP d[3])
           if(wikipage != 0) {
             type = "article"
             PG["ename"] = strip(d[3])
             PG["uname"] = strip(b[4])
             FlaG["search"] = "Yes"
           }
         }
         else {
           if(match(wikipage, "There were no results matching the query")) {
           }
           else {
             type = wiki_pagetype(wikipage)
             if(type == "article" || type == "dab") {  # WP sometimes sends a search directly to an article eg. Raymond MacDonald Alden -> Raymond Macdonald Alden
               match(wikipage,"\"wgTitle\":\"[^,]*,",b)
               split(b[0], d, "\"")
               gsub("&#039;","'",d[4])
               PG["uname"] = d[4]
               PG["ename"] = encode(d[4])
             } else {                 
                 type = "search"
                 a[1] = PG_HOME PG["ename"]
                 print "Error in type=search for: " PG["uname"] ". Saved HTML page with error message to " a[1] > "/dev/stderr"
                 print wikipage > a[1]
                 close(wikipage)
                 mylog(PG_LOG,"Error in type search for: " PG["uname"])
             }
           }
         }
      }

     # Landed on an article.
      if(type == "article") 
        core_logic(PG["uname"], PG["ename"])

     # Landed on a dab page. Run core_logic for each article.
      if(type == "dab") {
        FlaG["dab"] = "Yes"
        if(Debug) {
          print "  ____________main______________"
          print "  " PG["uname"]
          print "  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
        }
        get_dabs(PG["uname"], wikipage)
        ld = length(DaB)
        if(ld > 0) {
          di = 0
          while(di < ld) {
            di++
            if(core_logic(DaB[di]["uname"], DaB[di]["ename"]))
              break
          }
        }
      }

      if(WP["name"] == UNK)
        category_scan()     
      
     # Done looking. Now process and format output -------------------------------------------------------------

     # Format date strings

      if(WP["birth"] == UNK) WP["birth"] = ""
      if(WP["birth"] != "" || WP["death"] != "")
        wpdates = WP["birth"] "-" WP["death"]
      else
        wpdates = "AAAA-ZZZZ"
      if(PG["birth"] == UNK) PG["birth"] = ""
      if(PG["birth"] != "" || PG["death"] != "")
        pgdates = PG["birth"] "-" PG["death"]
      else
        pgdates = "AAAA-ZZZZ"

      if(Debug)
        print ""
      
      if(WP["name"] != UNK) {
        WP["output"] = sprintf("%s|%s|%s|%s|%s",str[1],PG["fullname"],WP["name"],pgdates,WP["findtype"])
        print WP["output"] >> outfile
        close(outfile)
        mylog(PG_LOG, "CLOSE")
      } else {
        print rawname >> outfile      
      }

      if(!Debug)
        rmfile(PG_TEMP "/*")  

    }
  }
  close(datafile)
}

# Core searching algo - e/uname equates to a legit WP article (not a dab, search, etc..)
#
#
function core_logic(uname, ename      ,article)
{

      if(Debug) 
        print "  ----------------------- CORE: " uname " -------------------"

      article = wget_wiki_source("http://en.wikipedia.org/wiki/Special:Export/" ename, PG_TEMP ename)
      if(length(article) < 10) {                    # safety check
        if(FlaG["redirect"] == "Yes")
          FlaG["redirect"] = "No"
        return 0
      }
      if(FlaG["redirect"] == "Yes") {
        uname = PG["uname"] = Title                 # Re-set working names in case of redirect
        ename = PG["ename"] = encode(Title)
        FlaG["redirect"] = "No"
      }

      if(article ~ "[[[ ]{0,2}Category:[ ]{0,2}"PG["birth"]" births[ ]{0,2}]]"  && article ~ "[[[ ]{0,2}Category:[ ]{0,2}"PG["death"]" deaths[ ]{0,2}]]") {
        if(false_positive(uname) == 0) {
          WP["name"] = uname
          WP["birth"] = PG["birth"]
          WP["death"] = PG["death"]
          WP["findtype"] = "Found: via dates"
          mylog(PG_LOG,"Found: " WP["name"] " : " PG["fullname"] " : via dates")
          return 1
        }
      } 

      if(WP["name"] == UNK && FlaG["hatnote"] == "Yes" && FlaG["dab"] == "No" ) {
        if(traverse_hatnotes(uname,ename))
          return 1
      }
    
      if(WP["name"] != UNK)
        return 1      
      else
        return 0
}


# category_scan
# Purpose: See if the first and last name of base PG name exists in both a birth and death category
# Return: If match, set as Possible 10
#
function category_scan(		z,h,c,d,e,f,g,i,j,cat)
{

  e = j = 0

  z = split(PG["name"],h," ")

  if( length(PG["birth"]) > 0 && length(PG["death"]) > 0) {
    if(Debug) 
      print "  ----------------------- category scan : " PG["name"] " -------------------"
    cat = wget_category("http://tools.wmflabs.org/ext-lnk-discover/sc/sc.php?category=" PG["birth"] "+births", PG_TEMP encode(PG["name"]) "." PG["birth"])
    if(cat ~ h[z]) {
      c = split(cat,d,"<br>")
      i = 1
      while(i <= c) {
        split(d[i],k,"(")
        g = split(k[1],f," ")
        if(f[g] == h[z] && f[1] == h[1]) {
          e++
          arrbirth[e] = d[i]
        }
        i++
      }
    }
  }
  if( length(PG["death"]) > 0 && e > 0 ) {
    cat = wget_category("http://tools.wmflabs.org/ext-lnk-discover/sc/sc.php?category=" PG["death"] "+deaths", PG_TEMP encode(PG["name"]) "." PG["death"])
    if(cat ~ h[z]) {
      c = split(cat,d,"<br>")
      i = 1
      while(i <= c) {
        split(d[i],k,"(")
        g = split(k[1],f," ")
        if(f[g] == h[z] && f[1] == h[1]) {
          j++
          arrdeath[j] = d[i]
        }
        i++
      }
    }
  }

  g = 0

  if(e > 0 && j > 0) {
    i = c = 1
    while(i <= e) {
      while(c <= j) {
        if(arrbirth[i] == arrdeath[c]) {
          g++
          arrmatch[g] = arrbirth[i]
        }
        c++
      }
      i++
    }
  }
  if(g > 0) {
    i = 0
    while(i < g) {
      i++
      log_possible("10", arrmatch[i])
    }
    return 0
  }

}

# Traverse and search hatnote pages, including all articles in a hatnoted dab page
#
function traverse_hatnotes(uname, ename		,c,a,i,d,e,pse,psu,psef,psuf,k,j,hatnoteS,ld,di)
{

  FlaG["hatnote"] = "Stop"  # ..stop recursive 

  if(Debug) 
    print "  ----------------------- traverse_hatnotes: " uname " -------------------"

  article = wget_str("http://en.wikipedia.org/wiki/" ename, PG_TEMP ename)

 # Create an array hatnoteS[] containing the hatnoted article names (uname and ename each)
  c = split(article,a,"(<div|</div>)")
  if(c){
    i = 1
    while(i < c) {
      if( match(a[i],"hatnote") && !match(a[i],"mainarticle") ) { # Skip {{main article}} templates.. any others?
        d = patsplit(a[i],pse,"/wiki/[^\"]*\"")
        patsplit(a[i],psu,"title=\"[^\"]*\"")
        j = 1
        while(j <= d) {
          split(pse[j],psef,"(/|\")")
          split(psu[j],psuf,"\"")
          k++
          j++
          if(match(psef[3],"[#]"))
            psef[3] = substr(psef[3],0,RSTART - 1) 
          if(match(psuf[2],"[#]"))
            psuf[2] = substr(psuf[2],0,RSTART - 1) 
          hatnoteS[k]["ename"] = strip(psef[3])
          match(psuf[2],"[#]")
          gsub("&#039;","'",psuf[2])
          hatnoteS[k]["uname"] = strip(psuf[2])
        }
        j = 1
      }
      i++
    }
  }

  if(length(hatnoteS)) {
    i = 1

    while(i <= length(hatnoteS)) {

      subarticle = wget_str("http://en.wikipedia.org/wiki/" hatnoteS[i]["ename"], PG_TEMP hatnoteS[i]["ename"])

     # For hatnoted dab pages
      if(wiki_pagetype(subarticle) == "dab") {
        FlaG["dab"] = "Yes"
        if(Debug) {
          print "  ______________________________"
          print "  " hatnoteS[i]["uname"]
          print "  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
        }
        get_dabs(hatnoteS[i]["uname"], subarticle)
        ld = length(DaB)
        if(ld > 0) {
          di = 1
          while(di <= ld) {
            #sleep(PG_SLEEP_SHORT) # A long dab page could rapid-fire WP
            if(core_logic(DaB[di]["uname"], DaB[di]["ename"])) {
              return 1
            }
            di++
          }
        }
      }

     # For non-dab hatnoted pages
      else {

        if(Debug) 
          print "  ----------------------- following hatnote " uname " -> " hatnoteS[i]["uname"] " -------------------"
        if(core_logic(hatnoteS[i]["uname"], hatnoteS[i]["ename"])) {
          return 1
        }
      }
      i++
    }
  }

  return 0

}

# Populate DaB[] with dab pange entries
#   DaB[x]["ename"] = URL-encoded name
#   DaB[x]["uname"] = Unencoded page name
#
function get_dabs(pguname,dabpage	,jsonin,jsonout,url,command,json,c,i,e,a,b,d,s,f)
{

  delete DaB

 # Get article link names (non-Encoded URL) via MediaWiki API
  json = wiki_api_parse(encode(pguname),"links")
  c = split(json,a,"[")
  i = 1
  e = 1
  while(i <= c) {
    if(match(a[i],"\"[*]\"")) {
      split(a[i],b,"]")
      if(b[2] !~ ":") {
        gsub(/[\\]\"/,"%22",b[2]) #Convert \" 
        split(b[2],d,"\"")
        gsub("&#039;","'",d[2])
        DaB[e]["uname"] = d[2]
        e++
      }
    }
    i++
  }

 # Find the equivilent Encoded URL names in the dab's HTML source
  i = 1
  f = 1
  while(i < e) {
    s = "<a href=\"[^\"]*\" title=\"" DaB[i]["uname"] "\""
    gsub(/\.|\(|\)|\?/,"\\\\&", s)
    if(match(dabpage, s, a)) {
      split(a[0],b,"\"")
      split(b[2],d,"/")
      if(match(d[3],"[#]"))
        d[3] = substr(d[3],0,RSTART - 1) 
      DaB[f]["ename"] = strip(d[3])
      f++
    }
    else {
      DaB[f]["ename"] = encode(DaB[f]["uname"])
      f++
    }
    i++
  }

#  i=0
#  while(i<f) {
#    print DaB[i]["uname"] " = " DaB[i]["ename"]
#    i++
#  }

}


# Populate vars with PG dates and fuzzydate flag
function get_pg_date(str	,bd)
{

    FlaG["fuzzydate"] = "No"

    split(str,bd,"-")
    PG["birth"] = bd[1]       # birth/death dates from catalog.csv
    PG["death"] = bd[2]

    if(PG["birth"] == "AAAA") 
      PG["birth"] = ""
    if(PG["death"] == "ZZZZ") 
      PG["death"] = ""
      
   # Set as fuzzy if one date is missing
    if( (PG["birth"] == "" && PG["death"] != "") || (PG["birth"] != "" && PG["death"] == "")  )
      FlaG["fuzzydate"] = "Yes"

}

# Log a possible match
#
function log_possible(number, wpuname	,str,ffp)
{

  if(false_positive(wpuname) == wpuname) {
    return
  }

  if( no_possibles(PG["fullname"],wpuname) ) {
    if(FlaG["log"] == "No") {
      WP["findtype"] = "Possible Type " number ": " wpuname 
      FlaG["log"] = "Yes"
    } else
      WP["findtype"] = "Possibles: Multiple matches see log file"

    str = "Possible Type " number ": " PG["fullname"] " = " wpuname " = " firstfull(PG["fullname"])
    mylog(PG_LOG,str)
  }
}

#Check for existence in match-possible (from old runs of pg2wp)
#
function no_possibles(pgname, wpname	,str,b,wp,pg)
{

  wp = strip(wpname)
  pg = strip(pgname)

  if(Possibles) {
    while ((getline str < Posfilename ) > 0) {
      split(str,b,":")
      if(wp == strip(b[2]) && pg == strip(b[1]) ) {
        close(Posfilename)
        return 0
      }
    }
  }
  close(Posfilename)
  return 1

}

# Return 1 if match in ~/match-false-positive
function false_positive(wpname		,str,b,c,d,i)
{

  if(FalsePositives) {
    while ((getline str < Fpfilename ) > 0) {
      split(str,b,":")
      c = split(b[2],d,";") # For multiple false postivies, separated by a " ; " in the .dat file. See example "Bull, Thomas"
      if(c == 0) {
        if(wpname == strip(b[2]) && PG["fullname"] == strip(b[1]) ) {   
          close(Fpfilename)
          return strip(b[2])
        }
      }
      if(c > 0) {
        i = 0
        while(i < c) {
          i++
          if(wpname == strip(d[i]) && PG["fullname"] == strip(b[1]) ) {
            close(Fpfilename)
            return strip(d[i])
          }
        }
      }
    }
    close(Fpfilename)
  }
  return 0

}

function skip_found(       str,b)
{
  if(Found) {
    while ((getline str < Foundfilename ) > 0) {
      split(str,b,":")
      if( PG["fullname"] == strip(b[1]) ) {
        close(Foundfilename)
        return 1
      }
    }
    close(Foundfilename)
  }
  return 0
}

function wiki_pagetype(page)
{

  if(match(page, "/wiki/Help:Disambiguation")) 
    return "dab"
  if(match(page, "This page or section lists people with the") )
    return "dab"
  if(match(page, "This page or section lists people that share the same") )
    return "dab"
  if(match(page, "There were no results matching the query"))
    return "dead"
  if(match(page, "consider checking the search results below"))
    return "search"
  if(match(page, "Wikipedia does not have an article with this exact name"))
    return "exact"
  return "article" # Might not actually be but shouldn't matter? Check it anyway.

}

# Convert " " to "_" for Wikipedia. 
#
function encode(str)
{

  gsub("&#039;","%27",str) # Sometimes this shows up in otherwise clear text
  gsub(" ","_",str)
  gsub("&","%26",str) 
  gsub("`","%60",str)
  gsub("/", "%2F",str)

  # See notes below before adding more encodes

  return str
}

function stats(total)
{

  print ""
  print "_______________________________________" >> PG_STATS
  print datafile " " Stamp >> PG_STATS
  print "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" >> PG_STATS

  print "WP Article     : " StatS["Article"] >> PG_STATS
  print "Special:Search : " StatS["Special:Search"] >> PG_STATS
  print "Special:Export : " StatS["Special:Export"] >> PG_STATS
  print "API template   : " StatS["API template"] >> PG_STATS
  print "API langlinks  : " StatS["API langlinks"] >> PG_STATS
  print "API links      : " StatS["API links"] >> PG_STATS
  print "API extlinks   : " StatS["API externallinks"] >> PG_STATS
  print "API backlinks  : " StatS["API backlinks"] >> PG_STATS
  print "Category Scan  : " StatS["Category Scan"] >> PG_STATS
  print "Open Library   : " StatS["Open Library"] >> PG_STATS
  print "API Timeouts   : " StatS["API timeout"] >> PG_STATS
  print "OL Timeouts    : " StatS["OL timeout"] >> PG_STATS

  total = StatS["Special:Search"] + StatS["Special:Export"] + StatS["Open Library"] + StatS["Category Scan"] + StatS["API template"] + StatS["API langlinks"] + StatS["API links"] + StatS["Article"]

  print "" >> PG_STATS
  print "Total          : " total >> PG_STATS

}

function usage()
{
  print ""
  print "Usage: lv2wp [OPTION] [PAREMETER]" > "/dev/stderr"
  print "Translate LibriVox <-> Wikipedia" > "/dev/stderr"
  print ""
  print "Options:"
  print "   -j Filename.cv   - a list of LV names (previously generated by lv.csh)"
  print "   -k Filename.cv   - the output."
  print "   -z Filename.log  - logging output."
  print ""
  exit 1
}

