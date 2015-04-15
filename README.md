# AD Group modification monitor
This script monitors the specified groups in Active Directory, and sends a change summarises the changes for each group. No email is sent if there are no changes

### Usage
Put the script and `settings.json` in the same directory. The script will create a file `GroupMembers.csv` the first time it is run.

### Settings
* **Groups** An array of groups you want to monitor.
* **SearchRoot** The base DN for finding your groups. Include LDAP:// prefix if set. Leave blank if you don't want to set it.
* **SMTPServer**, **EmailFrom**, **EmailTo** Settings for sending email.
* **EmailSubject** The subject of the email sent. Any occurance of `{group}` will be replaced with the name of the group.