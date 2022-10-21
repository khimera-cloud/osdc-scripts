RSYNC_URL:=https://download.samba.org/pub/rsync/src
RSYNC_VER:=3.2.3

help:
	@echo Valid targets: .deps, rsync, clean, distclean

default: help

#deps for debian
.deps:
	sudo apt install wget gcc libssl-dev libzstd-dev libxxhash-dev liblz4-dev expect openssh-client
	touch $@

#download source
rsync-$(RSYNC_VER).tar.gz:
	wget $(RSYNC_URL)/rsync-$(RSYNC_VER).tar.gz

#extract vanilla directory
rsync-$(RSYNC_VER): rsync-$(RSYNC_VER).tar.gz
	tar -xvzf rsync-$(RSYNC_VER).tar.gz
	touch $@

#configure into build directory
rsync-$(RSYNC_VER)-build: rsync-$(RSYNC_VER) .deps
	mkdir -p $@
	cd $@ && ../rsync-$(RSYNC_VER)/configure CFLAGS="-static"
	touch $@

#compile and strip binary
rsync: rsync-$(RSYNC_VER)-build
	cd rsync-$(RSYNC_VER)-build && make
	cp rsync-$(RSYNC_VER)-build/rsync .
	strip -s $@

#cleanup files
clean:
	rm -rvf rsync-$(RSYNC_VER) rsync-$(RSYNC_VER)-build rsync

#also delete downloaded source
distclean: clean
	rm -rvf rsync-$(RSYNC_VER).tar.gz .deps
