#!/bin/bash
# IMS Startup Script

cd /home/core/ims-debs

# Install kamailio packages
if [ -f kamailio_5.5.4-1_amd64.deb ]; then
    dpkg -i kamailio_5.5.4-1_amd64.deb
fi

if [ -f kamailio-ims-modules_5.5.4-1_amd64.deb ]; then
    dpkg -i kamailio-ims-modules_5.5.4-1_amd64.deb
fi

# Start Kamailio IMS
kamailio -f /etc/kamailio/kamailio.cfg -DD -E

echo 'IMS Started on port 5060'
