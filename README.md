# misc-scripts
Miscellaneous scripts to share

- pluskernel.sh

  Rebuild the CentOS 8 boot ISO with the kernel-plus packages from the CentOS-centosplus repository. This adds hardware support, especially for legacy systems that Red Hat has obsoleted in RHEL 8.
  
  Requirements:
  - Should run on CentOS 7+ and Fedora systems
  - Must install "mock" and add your user to the "mock" group (log out and back in after adding group)
  - Disk space in /var/lib/mock for the tree plus 2x the boot ISO (2 GB should be good)
  
