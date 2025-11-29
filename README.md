# Firewalla MSP Toolkit
Here are some sample scripts using Firewalla MSP APIs. If there's something you are interested in, open an issue to request.

In each script there are a few variables you need to set before using. See [Firewalla's MSP documentation](https://help.firewalla.com/hc/en-us/articles/5345330648083-Getting-Started-with-the-Firewalla-MSP-API) for tips on things like how to get your API key. 

## Targets

*  [``msptarget.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/maptarget.sh) Backup or search your MSP target lists Options [3.9 Nov 29]
    * ``msptarget.sh -b  [-o <owner_name|id>]``     # backup all target lists, -o can backup just one box or Global lists
    * ``msptarget.sh -j [-o <owner_name|id>]``      # JSON: Save complete list JSON objects to .json files.
    * ``msptarget.sh -s <id> [-o <owner_name|id>]`` # Show the Name and Contents of a specific list.
    * ``msptarget.sh -s [-o <owner_name|id>]``      # Show/list all target list IDs and Names (Name | ID).
    * ``msptarget.sh -s [-o <owner_name|id>]``      # Show/list all target list IDs and Names (Name | ID).


## Rules
*  [``msprulesbackup.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/msprulesbackup.sh) Backup or search your MSP target lists Options [1.0.1 Nov 23]
    * ``msprulesbackup.sh -j``                      # backup all target lists in json format
    * ``msprulesbackup.sh -s <id>``                 # show rules for a specific list ID
    * ``msprulesbackup.sh -s``                      # list all rules
