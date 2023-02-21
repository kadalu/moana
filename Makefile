prefix = /usr
VERSION?=0.0.0

all:
	: # do nothing

build:

	cd mgr && shards install && VERSION=$(VERSION) shards build --production --release

install: build

	install -D mgr/bin/kadalu \
                $(DESTDIR)$(prefix)/sbin/kadalu
	install -d sdk/python/kadalu_storage \
                $(DESTDIR)$(prefix)/lib/python3/dist-packages/kadalu_storage
	install -D extra/mount.kadalu \
                $(DESTDIR)/sbin/mount.kadalu
	install -m 700 -D extra/kadalu-mgr.service \
                $(DESTDIR)/lib/systemd/system/kadalu-mgr.service
	install -D -m 700 mgr/lib/volgen/templates/client.vol.j2 \
                $(DESTDIR)/var/lib/kadalu/templates/client.vol.j2
	install -D -m 700 mgr/lib/volgen/templates/storage_unit.vol.j2 \
                $(DESTDIR)/var/lib/kadalu/templates/storage_unit.vol.j2
	install -D -m 700 mgr/lib/volgen/templates/shd.vol.j2 \
                $(DESTDIR)/var/lib/kadalu/templates/shd.vol.j2

clean:
	: # do nothing

distclean: clean

uninstall:
	-rm -f $(DESTDIR)$(prefix)/sbin/kadalu
	-rm -f $(DESTDIR)$(prefix)/lib/python3/dist-packages/kadalu_storage
	-rm -f $(DESTDIR)/sbin/mount.kadalu
	-rm -f $(DESTDIR)/lib/systemd/system/kadalu-mgr.service


fmt-check:
	crystal tool format --check mgr/src types/src volgen/src volgen/spec sdk/crystal/src

lint:
	cd lint && shards install
	./lint/bin/ameba mgr/src types/src volgen/src volgen/spec sdk/crystal/src

fmt:
	crystal tool format mgr/src types/src volgen/src volgen/spec sdk/crystal/src

dist:
	rm -rf moana-$(VERSION)
	mkdir moana-$(VERSION)
	cp -r extra mgr sdk types volgen Makefile moana-$(VERSION)/
	tar cvzf moana-$(VERSION).tar.gz moana-$(VERSION)

deb: debclean
	VERSION=$(VERSION) $(MAKE) dist
	cp -r packaging/moana/debian moana-$(VERSION)/
	cd moana-$(VERSION) && debmake && debuild -eVERSION=$(VERSION)

debclean:
	rm -rf kadalu-storage-manager-dbgsym_*
	rm -rf kadalu-storage-manager_*
	rm -rf moana_*
	rm -rf python3-kadalu-storage_*
	rm -rf moana-*

.PHONY: all build install clean distclean uninstall fmt-check lint fmt dist deb debclean
