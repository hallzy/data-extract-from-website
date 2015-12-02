Extract From Website
====================

This script extracts the weekly deals from pickapart.ca and compares them with a
watchlist defined in the "products-to-look-for" file. If it finds that you
watchlisted items are on sale in the following week it will email you which ones
they are (defined in the "emails" file).

Debug
-----

Execute the debug script, and the script will only email the message to the
first email address in the "emails" file (usually this would be your email), and
will not delete any of the files that are generated by the script, so that you
can analyze the files and figure out what is happening.

Emails File
-----------

Just list each email address that will receive the email on a separate line.

This file also allows comments

sample:

```
# Comment
user1@domain.com
user2@domain.com
user3@domain.com
```

Products to look for File
-------------------------

Just list each item on a separate line.

This file also allows comments

sample:

```
# Comment
Any Plain Steel Wheels
Car Doors
Hoods
```

Note: It will also find fragments, so:

```
Steel Wheels
```

Will search for anything that contains "Steel Wheels", which includes the first
item on the sample list.

Note: This file is case insensitive.

tdtags and old-tdtags file
--------------------------

Both generated by the script

tdtags is populated based on the newest data from the website.

old-tdtags is a copy of tdtags before tdtags is populated with the new data (ie.
old-tdtags has all the data from the last execution, and tdtags has all the data
from the latest exectution).

We need both so that they can be compared to find out if a car has been added,
or removed from inventory.

Cars that have been added or removed are attached in the email with all the
details of the car.

Cronjob
-------

create a new cronjob by executing this:

```bash
crontab -e
```

and enter the below.

Since this website updates its page with new "on sale items" every week on Fridays at ~6pm,
use the following cronjob settings in order to run this:

```bash
0 18 * * 5 /PATH/TO/extract-from-pick-a-part
```

Note: 0 is the minute of the day, 18 is the hour of the day (18 is 6pm), * means
any day of the month, * means any month, 5 means Fridays. Therefore the script
runs every Friday at 6pm.

Also, the car inventory is updated on an hourly basis during business hours, so
add this cronjob to run the script only for the car portion (no sale items)
every day except Friday:

```bash
0 18 * * 0,1,2,3,4,6 /PATH/TO/extract-from-pick-a-part --cars-only
```

0 18 = 18:00 or 6:00pm
\*           = Any day of the month
\*           = Any Month
0,1,2,3,4,6 = Sunday, Monday, Tuesday, Wednesday, Thursday, or Saturday

Note that the car part will still run on friday as per the previous cronjob
task, but it will also check for on sale items.

