# Firewalla MSP Toolkit
Here are some sample scripts using Firewalla MSP APIs. If there's something you are interested in, open an issue to request.

In each script there are a few variables you need to set before using. See [Firewalla's MSP documentation](https://help.firewalla.com/hc/en-us/articles/5345330648083-Getting-Started-with-the-Firewalla-MSP-API) for tips on things like how to get your API key. 

## Target lists

*  [``msptarget.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/maptarget.sh) Backup or search your MSP target lists Options [3.9 Nov 29]
    * ``msptarget.sh -b  [-o <owner_name|id>]``     # backup all target lists, -o can backup just one box or Global lists
    * ``msptarget.sh -j [-o <owner_name|id>]``      # JSON: Save complete list JSON objects to .json files.
    * ``msptarget.sh -s <id> [-o <owner_name|id>]`` # Show the Name and Contents of a specific list.
    * ``msptarget.sh -s [-o <owner_name|id>]``      # Show/list all target list IDs and Names (Name | ID).
    * ``msptarget.sh -s [-o <owner_name|id>]``      # Show/list all target list IDs and Names (Name | ID).


## Rules
*  [``msprulesbackup.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/backup_msp_rules.sh) Backup or search your MSP Rules [2.0 May 16]
    * ``backup_msp_rules.sh -j``                      # backup all target lists in json format
    * ``backup_msp_rules.sh -s <id>``                 # show rules for a specific list ID
    * ``backup_msp_rules.sh -s``                      # list all rules

*  [``restore_msp_rules.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/restore_msp_rules.sh) Restore MSP rules Options [1.0 May 16]
    * ``restore_msp_rules.sh -l path(s) to files``     # restore the target list from the backup
    * ``restore_msp_rules.sh path(s) to files``        # A dry run will show what would happen but no restore will be done. 
