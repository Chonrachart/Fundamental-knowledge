# In /etc/systemd/system/[service-name].service

[Unit]  # this section define when and what order service to start
Description=OpenVSwitch [service-name] Service
Wants=network-online.target # soft dependency (not strict require if it fail service still tries to start)
After=network-online.target # strat this service after this

[Service] # this section define how service run
Type=oneshot # how service run (oneshot mean runas boot or use for setup)
User=root # run as user....
RemainAfterExit=yes # this is tell systemd to keeps the service state as active even the script is finish
ExecStart=/etc/network/openvswitch/[setup-file].bash # run which script
ExecStop=/usr/bin/ovs-vsctl del-br [bridge-name] # if service stop what to do

[Install] # this section define how service should start
WantedBy=multi-user.target # normal server boot 