# Firewalla-MSP-Toolkit
Here are some Sample scripts using Firewalla MSP APIs. If there's something you are interested in, open an issue to request.

In each script there are a few variables you need to set Before starting, see [Firewalla's MSP documentation](https://help.firewalla.com/hc/en-us/articles/5345330648083-Getting-Started-with-the-Firewalla-MSP-API).

*  [``msptarget.sh``](https://github.com/mbierman/Firewalla-MSP-Toolkit/blob/main/maptarget.sh) Backup or search your MSP target lists Options [1.0 Nov 21]
    * ``./msptarget.sh -b``          # backup all target lists
    * ``./msptarget.sh -s <id>``     # show targets for a specific list ID
    * ``./msptarget.sh -s``          # list all IDs
