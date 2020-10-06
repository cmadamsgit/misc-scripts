#!/bin/bash
#
# Rebuild the CentOS 8 installer ISO to include the centosplus kernel
# for added hardware support.  This should work on CentOS and Fedora
# systems.
#
# Requires:
# - mock (and permission to run mock - add your user to the mock group)
# - disk space in /var: 2x the ISO size
#
# If the latest CentOS 8 -boot.iso is found in the current directory
# when running this script, it'll be used; otherwise it'll be
# downloaded.
#
# Chris Adams <linux@cmadams.net>

# What platform
ARCH=x86_64
SQARCH=x86
VER=8

# what ISO image to rebuild: boot minimal dvd1 (XXX only boot supported)
WHAT=boot
[ -n "$1" ] && WHAT="$1"

set -e

# what to do inside mock
inmock ()
{
	# extract the ISO
	cd /tmp
	ISO=$(echo CentOS*iso)
	mkdir iso
	7z -oiso x $ISO
	rm -rf "iso/[BOOT]"

	# get the dracut options and extract some files
	eval $(lsinitrd iso/isolinux/initrd.img | grep "^Arguments:" | sed 's/^Arguments: /dracut_opt=(/;s/$/)/')
	for f in /.buildstamp /etc/multipath.conf; do
		lsinitrd -f $f iso/isolinux/initrd.img > $f
	done

	# build the installer initramfs
	v=$(rpm -q --qf "%{version}-%{release}.%{arch}" kernel-plus)
	dracut "${dracut_opt[@]}" --add uefi-lib --no-machineid --nolvmconf --nomdadmconf --no-hostonly --force --kver $v

	# put the kernel/initramfs in place for ISO boot
	rm -f iso/isolinux/vmlinuz iso/images/pxeboot/vmlinuz
	cp -p /boot/vmlinuz* iso/isolinux/vmlinuz
	ln iso/isolinux/vmlinuz iso/images/pxeboot/vmlinuz

	rm -f iso/isolinux/initrd.img iso/images/pxeboot/initrd.img
	cp -p /boot/initramfs*img iso/isolinux/initrd.img
	ln iso/isolinux/initrd.img iso/images/pxeboot/initrd.img

	# now have to extract the install root FS and swap out to match
	cd iso/images
	mkdir install
	7z -oinstall x install.img
	cd install/LiveOS
	mkdir rootfs
	mount -o rw,loop rootfs.img rootfs
	cd rootfs
	oldkern=$(echo lib/modules/*/vmlinuz)
	oldv=${oldkern%/*}
	oldv=${oldv##*/}
	rm -rf lib/modules/$oldv
	cp -a /lib/modules/$v lib/modules/
	rm -f boot/vmlinuz-$oldv boot/.vmlinuz-$oldv.hmac
	cp -a /boot/vmlinuz-$v /boot/.vmlinuz-$v.hmac boot/
	rm -f etc/ld.so.conf.d/kernel-$oldv.conf
	cp -a /etc/ld.so.conf.d/kernel-plus-$v.conf etc/ld.so.conf.d/
	# - also enable the centosplus repo
	sed -i 's/^\(enabled=\)0/\11/' etc/anaconda.repos.d/CentOS-centosplus.repo
	# - and get kernel only from plus
	sed -i '/^enabled=/a excludepkgs=kernel,kernel-modules*' etc/anaconda.repos.d/CentOS-Base.repo
	cd ..
	umount rootfs
	rmdir rootfs
	cd ../..
	rm -f install.img
	mksquashfs install install.img -comp xz -Xbcj $SQARCH
	rm -rf install
	cd ../..

	# if this is an ISO with packages, add the centosplus repo
	# XXX - need to find documentation on the treeinfo format to
	# make this work
#	if [ -e .treeinfo ]; then
#		cd iso
#		dnf --disablerepo=\* --enablerepo=centosplus reposync --download-metadata --newest-only --remote-time
#	fi

	# make a new ISO
	vol="$(isoinfo -i $ISO -d | grep "^Volume id:" | sed 's/.*: //')"
	rm $ISO
	genisoimage -o $ISO \
	    -input-charset utf-8 \
	    -eltorito-boot isolinux/isolinux.bin \
	    -eltorito-catalog isolinux/boot.cat \
	    -no-emul-boot -boot-load-size 4 -boot-info-table \
	    -eltorito-alt-boot -efi-boot images/efiboot.img -no-emul-boot \
	    -untranslated-filenames \
	    -translation-table \
	    -rational-rock \
	    -J -joliet-long \
	    -V "$vol" \
	    iso

	# make it bootable if dded onto USB
	isohybrid $ISO

	# make it testable
	implantisomd5 $ISO

	exit 0
}
[ "$1" = "mock" ] && inmock


# init the mock environment
MOCK="mock -r epel-$VER-$ARCH --disable-plugin=tmpfs --isolation=simple --enable-network"
MOCKNC="$MOCK --no-clean"
$MOCK clean

# what to install:
pkgs=
# - tools for managing the ISO
pkgs="$pkgs curl sed p7zip-plugins dracut squashfs-tools genisoimage syslinux isomd5sum"
# - kernel and firmware
pkgs="$pkgs kernel-plus kernel-plus-modules-extra iwl*firmware kmod-kvdo"
# - needed for the anaconda dracut module and deps
pkgs="$pkgs anaconda-dracut dracut-network dracut-live prefixdevname nfs-utils biosdevname plymouth-scripts fcoe-utils lldpad iscsi-initiator-utils lvm2 mdadm device-mapper-multipath nss-softokn-freebl rng-tools isomd5sum"
# - filesystem tools
pkgs="$pkgs e2fsprogs dosfstools xfsprogs gfs2-utils"
# - other utilities
pkgs="$pkgs vim-minimal less teamd kexec-tools"
# - branding
pkgs="$pkgs centos-logos"
# - other
pkgs="$pkgs alsa-lib"

# install all the things
$MOCK --install $pkgs --enablerepo=centosplus

# get the ISO into mock
cr=$(mktemp)
$MOCKNC --copyout /etc/centos-release $cr
rel=$(grep $VER $cr | sed 's/.* \('$VER'\.[0-9.]*\).*/\1/')
rm -f $cr
ISO="CentOS-$rel-$ARCH-$WHAT.iso"
ISOP="${ISO%.iso}-plus.iso"
if [ -e $ISO ]; then
	$MOCKNC --copyin $ISO /tmp/$ISO
else
	$MOCKNC --shell -- "cd /tmp; curl -LO http://mirror.centos.org/centos/$rel/isos/$ARCH/$ISO"
fi

# run the inside-mock bits
$MOCKNC --copyin $0 /tmp/doit
$MOCKNC --shell -- "/tmp/doit mock"

rm -f $ISOP
$MOCKNC --copyout /tmp/$ISO $ISOP
$MOCK clean
