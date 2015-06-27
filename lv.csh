#!/usr/bin/tcsh

# Customize path to tcsh above

# This 1-time program creates an index of all LibriVox authors in order to facilitate matching of Internet Archive hosted LibriVox works 
# back to LibriVox.
# For the purpose of adding LibriVox External Links to Wikipedia.
# September 2014
#
# Last run: September 30 2014 (0-10904)
# Last run: October 1 2014 (1-10905) (fixed "-" problem)
#

set START = 1
set END = 10905

# For example: https://librivox.org/author/10905 
#  was the last author at the time this script was run. 10906 was a dead link. Manually search for the last available number by trying 
#  different URLs until you find the last one that isn't a dead link. LibriVox adds them sequentially.

set LV_PATH="/home/username/lv/"              # customize this path (w/trailing slash)
source "$LV_PATH""set.csh"                    # customize paths in this file


# __________________End customizations _____________________________________

set stamp = `$DATE +"%m%d%H%M%S"`
set TEMP_DIRECTORY="$LV_PATH""temp"
set LV_TEMP="$TEMP_DIRECTORY""/lv-""$stamp""/"
$MKDIR "$LV_TEMP"
if ( ! -e "$LV_TEMP") then
  echo "Unable to create temp directory ""$LV_TEMP"
  goto myend
endif

#If cntrl-c interrupt, clean up temporary files - go to the myend: tag
onintr myend

if( -e "$LV_PATH"librivox-cache.cv) then
  set cache = "yes"
else
  set cache = "no"
endif

@ i = $START - 1
while ($i <= $END )

  @ i++

  # Skip if already found in a previous run
  if( "$cache" == "yes" ) then
    set oldwp = `$AWK -F\| -v s="$i" 'BEGIN{d = sprintf("^" s "\\|")} $0 ~ d {print $3}' "$LV_PATH"librivox-cache.cv`
    if("$oldwp" != "Unknown") then
      set output = `$AWK -F\| -v s="$i" 'BEGIN{d = sprintf("^" s "\\|")} $0 ~ d {print $0}' "$LV_PATH"librivox-cache.cv`
      echo "$output"
      continue
    endif
  endif

  set dob = ""
  set dod = ""
  set name = ""
  set wikiurl = ""
  set wikiname = "Unknown"
  set nameunder = ""

  $WGET -q -O- https://librivox.org/author/$i > "$LV_TEMP""lv.html"

  set dob = `$AWK /dod-dob/ "$LV_TEMP""lv.html" | $AWK -F\) 'NR==2 {split($1,s,"(-|–)"); gsub(/^[ \t]+|[ \t]+$/, "", s[1]); gsub("*|?","",s[1]); print s[1]}' RS=\(` # gsub strips white front&back
  if("$dob" == "") set dob = "AAAA"
  set dod = `$AWK /dod-dob/ "$LV_TEMP""lv.html" | $AWK -F\) 'NR==2 {split($1,s,"(-|–)"); gsub(/^[ \t]+|[ \t]+$/, "", s[2]); gsub("*|?","",s[2]); print s[2]}' RS=\(`
  if("$dod" == "") set dod = "ZZZZ"

  set name = `$AWK /dod-dob/ "$LV_TEMP""lv.html" | $AWK -F\< 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub("*|?","",$1); print $1}' RS=\>`
  if("$name" == "") set name = "Unknown"
  set wikiurl = `$AWK -F\" '/wikipedia/{print $2}' "$LV_TEMP""lv.html"`

  if("$wikiurl" == "") set wikiurl = "Unknown"

  if(`$AWK -v url="$wikiurl" -F\/ 'BEGIN{$0=url; print substr($3,1,1)}'` == "e") then # URL is for English wikipedia
    set wikiname = `$WGET -q -O- "$wikiurl" | $AWK -F\> '/<title>/{gsub(" - Wikipedia, the free encyclopedia","", $2); print $2}' | $AWK -F\< '{print $1}'`
    if("$wikiname" == "") set wikiname = "Unknown"
  endif

  if("$wikiname" == "") set wikiname = "Unknown"

  echo "$i""|""$name""|""$wikiname""|""$dob""-""$dod""|""$wikiurl"

  $SLEEP 1

end

myend:
 exit(1)

