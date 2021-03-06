#!/bin/bash

# declare -a CARS=("Saturn" "Caravan")

touch email-body.md

use_all_on_sale_items=1

if [[ "$1" == "DEBUG" ]]; then
  DEBUG=1
  isCarOnly=$2
else
  DEBUG=0
  isCarOnly=$1
fi

# Pre Script Settings#{{{
cd ~/Documents/git-repos/remote-github/data-extract-from-website

# Unset globbing
set -f

# Now readarray delimits with newlines
IFS='
'

# No case sensitivity for string matching
shopt -s nocasematch

readarray EMAILS < ./emails

# If debug is on, remove all emails except the first (which is mine)
NUM_OF_EMAILS=${#EMAILS[@]}
if (( DEBUG == 1 )); then
  debug_count=0
  for((i=0;i<NUM_OF_EMAILS;i++)); do
    echo "debug_count = $debug_count"
    if (( debug_count > 0 )); then
      EMAILS[$i]=""
      echo "EMAILS[i] = $EMAILS[$i]"
    fi
    ((debug_count++))
  done
fi

touch fetched_home_page_html
rm -rf fetched_home_page_html

echo "Downloading webpage: http://www.pickapart.ca/"
flag=0
wget -O fetched_home_page_html "http://www.pickapart.ca/" && flag=1

if (( flag == 1 )); then
  echo "Page Download Success"
else
  echo "Page Download Failed"
  echo "Script Failed to download on sale items" > email-body.md
  mutt -s "Pick a Part Alert FAILED" ${EMAILS[0]} < email-body.md
  exit
fi

cp -f fetched_home_page_html fetched_home_page_tdtag_with_newline

DATE_RANGE=$(command grep -Eo '[[:alpha:]]{3} [[:digit:]]{2}, [[:digit:]]{4} - [[:alpha:]]{3} [[:digit:]]{2}, [[:digit:]]{4}' fetched_home_page_tdtag_with_newline)

# DATE_RANGE is not set therefore the site is probably down or not working
if [ -z "$DATE_RANGE" ]; then
  echo "Page is not working properly"
  echo "The Pick a Part Website Appears to not be Working" > email-body.md
  mutt -s "Pick a Part Alert FAILED" ${EMAILS[0]} < email-body.md
  exit
fi

#}}}

echo -e "http://www.pickapart.ca/\n\n" | tee email-body.md email-body > /dev/null
# If no arguments were with the script, we can do this
if [[ -z "$isCarOnly" ]]
then
# Get Products that are on sale#{{{

readarray PRODUCTS < ./products-to-look-for


echo "Automated Pickapart Update" >> email-body
echo "# Automated Pickapart Update" >> email-body.md

{
  echo "Pick a Part has the following on sale from $DATE_RANGE:"
  echo " "
} | tee -a email-body.md email-body > /dev/null



# At the end of all td tags start a new line.
sed -i "s@</td>@</td>\n@g" fetched_home_page_tdtag_with_newline

# Open fetched_home_page_tdtag_with_newline#{{{
declare -a ARRAY
exec 10<&0
fileName="fetched_home_page_tdtag_with_newline"
exec < $fileName
let count=0
#}}}
# Each line gets stored in an array.#{{{
while read LINE; do
  ARRAY[$count]=$LINE
  ((count++))
done
#}}}
# Close fetched_home_page_tdtag_with_newline#{{{
exec 0<&10 10<&-
#}}}

# Used to find the lines we need.
regex="<td align='center' valign='top'>[[:print:]]*</td>"

touch tdtags_products_on_sale
rm -rf tdtags_products_on_sale
touch tdtags_products_on_sale

ELEMENTS=${#ARRAY[@]}
firstLine=0


# make tdtags_products_on_sale file that contains only the useful information.
for((i=0;i<ELEMENTS;i++)); do
  if [[ ${ARRAY[${i}]} =~ $regex ]] ; then
    if (( firstLine < 1 )); then
      echo "${BASH_REMATCH[0]}" > tdtags_products_on_sale
      let firstLine=$firstLine+1
    else
      echo "${BASH_REMATCH[0]}" >> tdtags_products_on_sale
    fi
  fi
done

# Remove all unwanted values from tdtags_products_on_sale
# This generates a file tdtags_products_on_sale that contains the item on one line, followed by
# the price on the second line.
# remove "<td align='center' valign='top'>" from each line
sed -i "s@<td align='center' valign='top'>@@g" tdtags_products_on_sale
# remove </td> tags
sed -i "s@</td>@@g" tdtags_products_on_sale
# removes the <br> tag and replaces it with " - ". That way the product name and
# price are separated by a " - "
sed -i "s@<br>@ - @g" tdtags_products_on_sale

# Put the fetched items from tdtags_products_on_sale into an array
readarray FETCHED_ITEMS < ./tdtags_products_on_sale
NUM_PRODUCTS_FOUND=0

if (( use_all_on_sale_items == 0 )); then
  echo "Searching webpage for items of interest:"
  for PRODUCT in "${PRODUCTS[@]}"
  do
    # Skip comments when parsing
    [[ ${PRODUCT:0:1} == "#" ]] && continue
    # Skip empty lines when parsing
    [[ ${PRODUCT:1:1} == "" ]] && continue

    # Remove trailing newline from the name
    PRODUCT=$(echo "${PRODUCT}" | tr -d '\n')

    # See if PRODUCT is found on the webpage
    # If it is, print it to the console, and append it to email-body.md file.
    for FETCHED_ITEM in "${FETCHED_ITEMS[@]}"
    do
      if [[ $FETCHED_ITEM =~ $PRODUCT ]]; then
        echo -n "* $FETCHED_ITEM" >> email-body.md
        echo -n "- $FETCHED_ITEM" >> email-body
        echo -n "Found:  $FETCHED_ITEM"
        ((NUM_PRODUCTS_FOUND++))
      fi
    done

  done
else
  for FETCHED_ITEM in "${FETCHED_ITEMS[@]}"
  do
    echo -n "* $FETCHED_ITEM" >> email-body.md
    echo -n "- $FETCHED_ITEM" >> email-body
    echo -n "Found:  $FETCHED_ITEM"
    ((NUM_PRODUCTS_FOUND++))
  done
fi

# No products found.
if [[ $NUM_PRODUCTS_FOUND == 0 ]]; then
    echo "Pick a Part has nothing on sale this week ($DATE_RANGE)." | tee -a email-body.md email-body > /dev/null
fi

#remove duplicate entries in email-body.md
awk '!a[$0]++' email-body.md > tmp && mv tmp email-body.md
awk '!a[$0]++' email-body > tmp && mv tmp email-body
#}}}
else
  # -1 will indicate that this part was never run, so I know whether or not to
  # send an email.
  NUM_PRODUCTS_FOUND=-1
fi

readarray CARS < ./cars-to-find
let new_car_total_count=0
let old_car_total_count=0
for CAR in "${CARS[@]}"
do
  CAR=${CAR//$'\n'/}
  rm -rf "${CAR}_tdtags_old_cars"
  cp "${CAR}_tdtags_latest_cars" "${CAR}_tdtags_old_cars"
  if [ "$?" -eq 1 ]; then
    touch "${CAR}_tdtags_old_cars"
  fi
# Find new or missing cars on the lot#{{{
echo "Downloading car list from webpage: http://parts.pickapart.ca/index.php"
# This submits a form on pickapart.ca to get a list of ${CAR}s in the lot.
flag=0
curl --form-string 'md=submit' --form-string "model=${CAR}" 'http://parts.pickapart.ca/index.php' > "${CAR}_list_html" && flag=1

if (( flag == 1 )); then
  echo "Page Download Success"
else
  echo "Page Download Failed"
  echo "Script Failed to download car list" > email-body.md
  mutt -s "Pick a Part Alert FAILED" ${EMAILS[0]} < email-body.md
  exit
fi

dos2unix "${CAR}_list_html"

# Remove all lines from html that are not necessary at all (before the parts we don't need, and after)#{{{

# Open ${CAR}_list_html
declare -a ARRAY
exec 10<&0
fileName="${CAR}_list_html"
exec < "$fileName"
let count=0

# Each line gets stored in an array.
while read LINE; do
  ARRAY[$count]=$LINE
  ((count++))
done

exec 0<&10 10<&-

# Used to find the lines we need.
regex="<tr [[:print:]]*photo-group[[:print:]]*</tr>"
#}}}

# make tdtags file that contains only the useful information.#{{{

touch "${CAR}_tdtags_latest_cars"
rm -rf "${CAR}_tdtags_latest_cars"
touch "${CAR}_tdtags_latest_cars"

ELEMENTS=${#ARRAY[@]}
firstLine=0


for((i=0;i<ELEMENTS;i++)); do
  if [[ ${ARRAY[${i}]} =~ $regex ]] ; then
    if (( firstLine < 1 )); then
      echo "${BASH_REMATCH[0]}" > "${CAR}_tdtags_latest_cars"
      let firstLine=$firstLine+1
    else
      echo "${BASH_REMATCH[0]}" >> "${CAR}_tdtags_latest_cars"
    fi
  fi
done

# At the end of all td tags start a new line.
sed -i "s@</td>@</td>\n@g" "${CAR}_tdtags_latest_cars"


# Put urls on there on lines
sed -i "s@http@\nhttp@g" "${CAR}_tdtags_latest_cars" | sed -in "s/\(^http[s]*:[a-Z0-9/.=?_-]*\)\(.*\)/\1/p"
# Delete all lines containing <tr bgcolor=
sed -i '/<tr bgcolor=/d' "${CAR}_tdtags_latest_cars"
# Delete everything after the url on the line
sed -i 's/JPG.*/JPG/' "${CAR}_tdtags_latest_cars"

# remove "<td>" from each line
sed -i "s@<td>@@g" "${CAR}_tdtags_latest_cars"
# remove "</td>" from each line
sed -i "s@</td>@@g" "${CAR}_tdtags_latest_cars"
# remove "</tr>" from each line
sed -i "s@</tr>@@g" "${CAR}_tdtags_latest_cars"
#}}}

# Populate Arrays for the data for the new cars#{{{

# Open "${CAR}_tdtags_latest_cars"
declare -a PICS_START_POINT
declare -a URLS
declare -a HOW_MANY_PICS
declare -a DATE_ADDED
declare -a CAR_MODEL
declare -a CAR_YEAR
declare -a CAR_BODY_STYLE
declare -a CAR_ENGINE
declare -a CAR_TRANSMISSION
declare -a CAR_DESCRIPTION
declare -a CAR_STOCK_NUMBERS
exec 10<&0
fileName="${CAR}_tdtags_latest_cars"
exec < "$fileName"
let date_added_count=0
let car_model_count=0
let car_year_count=0
let car_body_style_count=0
let car_engine_count=0
let car_transmission_count=0
let car_description_count=0
let car_stock_array_count=0

# CAR_ARRAY now contains all the car information for ${CAR}s.
# Note that bash does not have 2D arrays, so it is stored in a 1D array.

# We first need to look for URLs. These are the URLs for the Pictures.

let count=0
let how_many_pics=0

touch "${CAR}_image_links"
rm -rf "${CAR}_image_links"
touch "${CAR}_image_links"

let id=0
let skip=10

while read LINE; do
  # Get date added
  if (( skip < 10 )); then
    ((skip++))
  elif [[ "$LINE" =~ http ]] ; then
    if (( how_many_pics == 0 )); then
      echo "vehicle $id" >> "${CAR}"_image_links
      PICS_START_POINT[$id]=$count
    fi
    ((how_many_pics++))
    URLS[$count]=$LINE
    echo "$LINE" >> "${CAR}"_image_links
  else
    skip=1
    HOW_MANY_PICS[$id]=$how_many_pics
    ((id++))
    how_many_pics=0
  fi
  ((count++))
done

# Delete all lines containing "http"
sed -i '/http/d' "${CAR}_tdtags_latest_cars"

# Now close the file so we can reopen it for the next part
exec 0<&10 10<&-

exec 10<&0
fileName="${CAR}_tdtags_latest_cars"
exec < "$fileName"

# index 0 = Date added
# index 1 = Make
# index 2 = Model
# index 3 = Year
# index 4 = Body Style (ex. 4DSDN, 2DCPE etc)
# index 5 = Engine
# index 6 = Transmission
# index 7 = Description
# index 8 = Row # (The row at the lot that the car is in)
# index 9 = Stock #

# index 10 = Date added for the next car
# etc
# Each line gets stored in an array.

let count=0
while read LINE; do
  # Get date added
  if (( count % 10 == 0 )); then
    DATE_ADDED[$date_added_count]=$LINE
    ((date_added_count++))
  # Get car models
  elif (( count % 10 == 2 )); then
    CAR_MODEL[$car_model_count]=$LINE
    ((car_model_count++))
  # Get car year
  elif (( count % 10 == 3 )); then
    CAR_YEAR[$car_year_count]=$LINE
    ((car_year_count++))
  # Get car body styles
  elif (( count % 10 == 4 )); then
    CAR_BODY_STYLE[$car_body_style_count]=$LINE
    ((car_body_style_count++))
  # Get car engine type
  elif (( count % 10 == 5 )); then
    CAR_ENGINE[$car_engine_count]=$LINE
    ((car_engine_count++))
  # Get car transmission type
  elif (( count % 10 == 6 )); then
    CAR_TRANSMISSION[$car_transmission_count]=$LINE
    ((car_transmission_count++))
  # Get car description
  elif (( count % 10 == 7 )); then
    CAR_DESCRIPTION[$car_description_count]=$LINE
    ((car_description_count++))
  # Get stock numbers
  elif (( count % 10 == 9 )); then
    CAR_STOCK_NUMBERS[$car_stock_array_count]=$LINE
    ((car_stock_array_count++))
  fi

  ((count++))
done

exec 0<&10 10<&-

# number of cars = size of array / 10
num_of_cars_current=$car_stock_array_count
#}}}

# Populate Arrays for the data for the old cars#{{{

# Open tdtags
declare -a OLD_CAR_MODEL
declare -a OLD_CAR_YEAR
declare -a OLD_CAR_BODY_STYLE
declare -a OLD_CAR_ENGINE
declare -a OLD_CAR_TRANSMISSION
declare -a OLD_CAR_DESCRIPTION
declare -a OLD_CAR_STOCK_NUMBERS
exec 10<&0
fileName="${CAR}_tdtags_old_cars"
exec < "$fileName"
let old_car_model_count=0
let old_car_year_count=0
let old_car_body_style_count=0
let old_car_engine_count=0
let old_car_transmission_count=0
let old_car_description_count=0
let old_car_stock_array_count=0

let count=0
# CAR_ARRAY now contains all the car information for ${CAR}s.
# Note that bash does not have 2D arrays, so it is stored in a 1D array.

while read LINE; do
  # Get car models
  if (( count % 10 == 2 )); then
    OLD_CAR_MODEL[$old_car_model_count]=$LINE
    ((old_car_model_count++))
  # Get car year
  elif (( count % 10 == 3 )); then
    OLD_CAR_YEAR[$old_car_year_count]=$LINE
    ((old_car_year_count++))
  # Get car body styles
  elif (( count % 10 == 4 )); then
    OLD_CAR_BODY_STYLE[$old_car_body_style_count]=$LINE
    ((old_car_body_style_count++))
  # Get car engine type
  elif (( count % 10 == 5 )); then
    OLD_CAR_ENGINE[$old_car_engine_count]=$LINE
    ((old_car_engine_count++))
  # Get car transmission type
  elif (( count % 10 == 6 )); then
    OLD_CAR_TRANSMISSION[$old_car_transmission_count]=$LINE
    ((old_car_transmission_count++))
  # Get car description
  elif (( count % 10 == 7 )); then
    OLD_CAR_DESCRIPTION[$old_car_description_count]=$LINE
    ((old_car_description_count++))
  # Get stock numbers
  elif (( count % 10 == 9 )); then
    OLD_CAR_STOCK_NUMBERS[$old_car_stock_array_count]=$LINE
    ((old_car_stock_array_count++))
  fi

  ((count++))
done

exec 0<&10 10<&-
#}}}

# Find new cars on the lot#{{{

let found=0
let count=0
let new_car_array_count=0
declare -a NEW_CARS_ARRAY

# Find New Cars
for NEW_NUMBER in "${CAR_STOCK_NUMBERS[@]}"
do
  for OLD_NUMBER in "${OLD_CAR_STOCK_NUMBERS[@]}"
  do
    # OLD_NUMBER=$(echo ${OLD_NUMBER} | tr -d '\n')
    # Remove trailing newlines
    if [[ $NEW_NUMBER == "$OLD_NUMBER" ]]; then
      # new number exists in old number
      found=1
      break
    fi
  done
  # If the number was not found, we have a new car
  if (( "$found" == "0" )); then
    echo "New Car: $count - $NEW_NUMBER"
    NEW_CARS_ARRAY[$new_car_array_count]=$count
    ((new_car_array_count++))
    ((new_car_total_count++))
  fi
  ((count++))
  found=0
done
#}}}

#Find cars that have been removed#{{{

let found=0
let count=0
let old_car_array_count=0
declare -a OLD_CARS_ARRAY

# Find Cars that have been removed
for OLD_NUMBER in "${OLD_CAR_STOCK_NUMBERS[@]}"
do
  # OLD_NUMBER=$(echo ${OLD_NUMBER} | tr -d '\n')
  for NEW_NUMBER in "${CAR_STOCK_NUMBERS[@]}"
  do
    # Remove trailing newlines
    if [[ $NEW_NUMBER == "$OLD_NUMBER" ]]; then
      # new number exists in old number
      found=1
      break
    fi
  done
  # If the number was not found, we have a new car
  if (( "$found" == "0" )); then
    echo "Old Car: $count - $OLD_NUMBER"
    OLD_CARS_ARRAY[$old_car_array_count]=$count
    ((old_car_array_count++))
    ((old_car_total_count++))
  fi
  ((count++))
  found=0
done
#}}}

# Echo how many cars are still on the lot iff at least one car has been removed
# or added.
if (( "$old_car_array_count" > "0" || "$new_car_array_count" > "0" )); then
  if (( "$NUM_PRODUCTS_FOUND" != "-1" )); then
    echo -e "\n\n" | tee -a email-body.md email-body > /dev/null
  fi
  echo "# _______________________________________________________" >> email-body.md
  echo " "
  echo "## ${CAR} (${num_of_cars_current} On the Lot)" >> email-body.md
  echo "${CAR} (${num_of_cars_current} On the Lot)" >> email-body
  echo " "
fi

# Append new cars to email body#{{{

if (( "$new_car_array_count" > "0" )); then
  echo "  New ${CAR}s:" >> email-body
  {
    echo "### New ${CAR}s:"
    echo "|Pictures|Date Added|Model|Year|Body Style|Engine|Transmission|Description|Stock #|"
    echo "|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|"
  } >> email-body.md


declare -a PICS_START_POINT
declare -a URLS
declare -a HOW_MANY_PICS


  for NEW_CAR in "${NEW_CARS_ARRAY[@]}"
  do
    num_cars=${HOW_MANY_PICS[$NEW_CAR]}
    start_point=${PICS_START_POINT[$NEW_CAR]}
    end_point=$((start_point+num_cars))
    pics=""
    pic_num=1
    for((i=start_point;i<end_point;i++)); do
      if (( pic_num > 3 )); then
        pic_num=1
      fi
      pics="$pics [$pic_num](${URLS[$i]})"
      ((pic_num++))
    done

    echo "|$pics|${DATE_ADDED[${NEW_CAR}]}|${CAR_MODEL[${NEW_CAR}]}|${CAR_YEAR[${NEW_CAR}]}|${CAR_BODY_STYLE[${NEW_CAR}]}|${CAR_ENGINE[${NEW_CAR}]}|${CAR_TRANSMISSION[${NEW_CAR}]}|${CAR_DESCRIPTION[${NEW_CAR}]}|${CAR_STOCK_NUMBERS[${NEW_CAR}]}|" >> email-body.md

    echo "    - Added on ${DATE_ADDED[${NEW_CAR}]} - ${CAR_YEAR[${NEW_CAR}]} ${CAR_MODEL[${NEW_CAR}]} - ${CAR_BODY_STYLE[${NEW_CAR}]} - ${CAR_ENGINE[${NEW_CAR}]} - ${CAR_TRANSMISSION[${NEW_CAR}]} Transmission - ${CAR_DESCRIPTION[${NEW_CAR}]} - ${CAR_STOCK_NUMBERS[${NEW_CAR}]}" >> email-body

  done
fi


#}}}

# Append cars removed from the lot to the email body#{{{

if (( "$old_car_array_count" > "0" )); then
  if (( "$new_car_array_count" > "0" )); then
    echo -e "\n" | tee -a email-body.md email-body > /dev/null
  fi
  echo " "
    echo "  ${CAR}s that have been removed from the lot:" >> email-body
  {
    echo "### ${CAR}s that have been removed from the lot:"
    echo "|Model|Year|Body Style|Engine|Transmission|Description|Stock #|"
    echo "|:-:|:-:|:-:|:-:|:-:|:-:|:-:|"
  } >> email-body.md


  for OLD_CAR in "${OLD_CARS_ARRAY[@]}"
  do
    echo "|${OLD_CAR_MODEL[${OLD_CAR}]}|${OLD_CAR_YEAR[${OLD_CAR}]}|${OLD_CAR_BODY_STYLE[${OLD_CAR}]}|${OLD_CAR_ENGINE[${OLD_CAR}]}|${OLD_CAR_TRANSMISSION[${OLD_CAR}]}|${OLD_CAR_DESCRIPTION[${OLD_CAR}]}|${OLD_CAR_STOCK_NUMBERS[${OLD_CAR}]}|" >> email-body.md

    echo "    - ${OLD_CAR_YEAR[${OLD_CAR}]} ${OLD_CAR_MODEL[${OLD_CAR}]} - ${OLD_CAR_BODY_STYLE[${OLD_CAR}]} - ${OLD_CAR_ENGINE[${OLD_CAR}]} - ${OLD_CAR_TRANSMISSION[${OLD_CAR}]} Transmission - ${OLD_CAR_DESCRIPTION[${OLD_CAR}]} - ${OLD_CAR_STOCK_NUMBERS[${OLD_CAR}]}" >> email-body

  done
fi


#}}}

unset NEW_CARS_ARRAY
unset OLD_CARS_ARRAY
unset CAR_STOCK_NUMBERS
unset OLD_CAR_STOCK_NUMBERS

#}}}
done

# Email#{{{

# If no new cars, or no cars removed, set a flag to not send an email.
sendMail=1
if (( "$old_car_total_count" == "0" && "$new_car_total_count" == "0" && "$NUM_PRODUCTS_FOUND" == "-1" )); then
  if (( "$DEBUG" == "1" )); then
    echo "This email would not send. This is a debug email" | tee -a email-body.md email-body
    sendMail=1
  else
  sendMail=0
  fi
fi

# only send mail, if sendMail is 1, or if debug is on.
if (( "$sendMail" == "1" )); then
  # Used to echo if an email is commented
  # COUNT=0

  # Converting markdown to a pdf
  echo "Converting email-body to a pdf..."
  gimli -stylesheet github-markdown.css -f email-body.md
  DATE_VAR=$(date +%F)
  TIME_VAR=$(date +%H)
  mv email-body.pdf "${DATE_VAR}_${TIME_VAR}".pdf
  echo "Sending emails..."
  for EMAIL in "${EMAILS[@]}"
  do
    # This stuff is for comment checking. I prefer not to check so that if an
    # email is commented I get a delivery status notification failure)
    # # Used to echo if the line is commented
    # # Skip comments when parsing
    # # Also if it is commented print to the log and console that it is commented.
    # COUNT=$((COUNT + 1))
    # [[ ${EMAIL:0:1} == "#" ]] && echo "Line #$COUNT is Commented" && continue
    # Skip empty lines when parsing
    [[ ${EMAIL:1:1} == "" ]] && continue

    if (( "$NUM_PRODUCTS_FOUND" == "-1" )); then
      now=$(date +'%b %d, %Y')
      mutt -s "Pick a Part Alert: $now" $EMAIL -a "${DATE_VAR}_${TIME_VAR}".pdf < email-body
    else
      mutt -s "Pick a Part Alert: $DATE_RANGE" $EMAIL -a "${DATE_VAR}_${TIME_VAR}".pdf < email-body
    fi

    # -n removes trailing newlines
    echo -n "Sent to $EMAIL"
  done
fi

#}}}

# Cleanup#{{{

unset IFS
set +f

#}}}

