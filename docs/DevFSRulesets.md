
# Vessel devfs rules

The vessel router requires both pf and bpf device nodes to be exposed.  To do this, the proper
devfs rules need to be used with the router jail.  Further, a vessel jail needs to expose bpf
if it wants to use vessel networks so that dhclient can communicate with the vessel dhcp server.

That leaves a few options:

1. Tell the user how to configure devfs add add the appropriate rules to devfs.conf.
2. Install a a rules file and tell the user how to set devfs_rulesets.conf
3. Install a rules file and an rc script so that we can tell the user to set vessel_enable=YES
and that will allow the rc script to call devfs_rulesets_from_file on the vessel ruleset file.

I prefer option 3 so there is less inertia and manual setup to use vessel and vessel networking.

## Useful context

* rc.subr parses the devfs.rules file.  The relevant function to call from a rc script is 
devfs_rulesets_from_file <filename>
* I'll install my rules file to /usr/local/etc/vessel/vessel_devfs.rules
* I'll have a rule for vessel-router and vessel-networked-jail (60100 and 60101 respectively)
* If a user needs their own devfs rules, they can include those.