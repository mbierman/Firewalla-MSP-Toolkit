# Firewalla-MSP-Toolkit
Here are some sample scripts using Firewalla MSP APIs. If there's something you are interested in, open an issue to request.

In each script there are a few variables you need to set before using. See [Firewalla's MSP documentation](https://help.firewalla.com/hc/en-us/articles/5345330648083-Getting-Started-with-the-Firewalla-MSP-API) for tips on things like how to get your API key. 

*  [``msptarget.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/maptarget.sh) Backup or search your MSP target lists Options [3.8 Nov 22]
    * ``./msptarget.sh -b``          # backup all target lists
    * ``./msptarget.sh -j``          # backup all target lists in json format
    * ``./msptarget.sh -s <id>``     # show targets for a specific list ID
    * ``./msptarget.sh -s``          # list all IDs

*  [``msprulesbackup.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/maptarget.sh) Backup or search your MSP target lists Options [1.0 Nov 22]
    * ``./msptarget.sh -j``          # backup all target lists in json format
    * ``./msptarget.sh -s <id>``     # show rules for a specific list ID
    * ``./msptarget.sh -s``          # list all rules
