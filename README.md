Extract From Website
====================

This script extracts the weekly deals from pickapart.ca and compares them with a
watchlist defined in the "products-to-look-for" file. If it finds that you
watchlisted items are on sale in the following week it will email you which ones
they are (defined in the "emails" file).

Emails File
-----------

Just list each email address that will receive the email on a separate line.

sample:

```
user1@domain.com
user2@domain.com
user3@domain.com
```

Products to look for File
-------------------------

Just list each item on a separate line.

sample:

```
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

Cronjob
-------

Since this website updates its page with new "on sale items" every week on ??,
use the following cronjob settings in order to run this:

```bash
* * * * * /PATH/TO/extract-from-pick-a-part
```

Note: I do not yet know when to update. The example above runs the script once
every minute.

