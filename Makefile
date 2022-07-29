prefix = /usr

all:
	: # do nothing

build:

	cd mgr && shards install && shards build

install: build

	install -D mgr/bin/kadalu \
                $(DESTDIR)$(prefix)/sbin/kadalu
	install -d sdk/python/kadalu \
                $(DESTDIR)$(prefix)/lib/python3/dist-packages/kadalu_storage
	install -D extra/mount.kadalu \
                $(DESTDIR)/sbin/mount.kadalu
	install -m 700 -D extra/kadalu-mgr.service \
                $(DESTDIR)/lib/systemd/system/kadalu-mgr.service

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

.PHONY: all build install clean distclean uninstall fmt-check lint fmt
