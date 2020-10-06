# misc-scripts
Miscellaneous scripts to share

- pluskernel.sh

  Rebuild the CentOS 8 boot ISO with the kernel-plus packages from the CentOS-centosplus repository. This adds hardware support, especially for legacy systems that Red Hat has obsoleted in RHEL 8.
  
  Requirements:
  - Should run on CentOS 7+ and Fedora systems
  - Must install "mock" and add your user to the "mock" group (log out and back in after adding group)
  - Disk space in /var/lib/mock for the tree plus 2x the boot ISO (2 GB should be good)
  
  Notes:
  - While the resulting ISO should boot and install the kernel-plus packages rather than base kernel packages, it does NOT enable the centosplus repo on the installed system. You'll need to do this (either in a kickstart %post or after install) to get kernel-plus updates. You can run `dnf config-manager --enable centosplus`
  - Having the repo enabled during install may pull in other centosplus replacement packages over base OS packages... haven't tried to limit that.
 
