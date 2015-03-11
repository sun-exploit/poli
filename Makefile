r := $(shell svnversion -nc .. | sed -e 's/^[^:]*://;s/[A-Za-z]//')
tmpdir := $(shell mktemp -ud)
pwd := $(shell pwd)

COMMON_UTILS=../poli_utils/pcsd_{common,config,events,log}.py \
			 ../poli_utils/__init__.py ../poli_utils/pcsd_daemon.py
COMMON_MODULES=../poli_modules/__init__.py

# Modules that should be installed for the client
CLIENT_MODULES := $(COMMON_MODULES) \
	$(shell grep "PCSD_CLIENT" crcnetd/modules/* | cut -f1 -d':' | xargs)
CLIENT_UTILS=$(COMMON_UTILS) crcnetd/_utils/pcsd_clientserver.py \
			 crcnetd/_utils/interfaces.py crcnetd/_utils/dhcpd.py \
			 crcnetd/_utils/pcsd_tc.py

# Modules that should be installed for the server
SERVER_MODULES := $(COMMON_MODULES) \
	$(shell grep "PCSD_SERVER" crcnetd/modules/* | cut -f1 -d':' | xargs)
SERVER_UTILS=$(COMMON_UTILS) \
			 crcnetd/_utils/pcsd_{ca,cfengine,email,server,service,session}.py

all:

install-client:
	install -d -m755 -o pcs -g pcs \
		$(DESTDIR)/usr/share/pcsd/{crcnetd,resources}
	install -d -m755 -o pcs -g pcs \
		$(DESTDIR)/usr/share/pcsd/crcnetd/{_utils,modules}
	install -m644 -o pcs -g pcs crcnetd/*.py \
		$(DESTDIR)/usr/share/pcsd/crcnetd/
	install -m644 -o pcs -g pcs $(CLIENT_MODULES) \
		$(DESTDIR)/usr/share/pcsd/crcnetd/modules/
	install -m644 -o pcs -g pcs $(CLIENT_UTILS) \
		$(DESTDIR)/usr/share/pcsd/crcnetd/_utils/
	install -m644 -o pcs -g pcs resources/* \
		$(DESTDIR)/usr/share/pcsd/resources/
	install -d -m755 -o pcs -g pcs $(DESTDIR)/usr/share/doc/pcsd/
	install -m644 -o pcs -g pcs docs/* $(DESTDIR)/usr/share/doc/pcsd/
	install -d -m755 -o pcs -g pcs $(DESTDIR)/usr/sbin/
	install -m755 -o pcs -g pcs crcnet-monitor \
		$(DESTDIR)/usr/sbin/crcnet-monitor

install-server:
	install -d -m755 -o pcs -g pcs \
		$(DESTDIR)/usr/share/pcsd/{crcnetd,templates,dbschema}
	install -d -m755 -o pcs -g pcs \
		$(DESTDIR)/usr/share/pcsd/crcnetd/{_utils,modules}
	install -m644 -o pcs -g pcs crcnetd/*.py \
		$(DESTDIR)/usr/share/pcsd/crcnetd/
	install -m644 -o pcs -g pcs $(SERVER_MODULES) \
		$(DESTDIR)/usr/share/pcsd/crcnetd/modules/
	install -m644 -o pcs -g pcs $(SERVER_UTILS) \
		$(DESTDIR)/usr/share/pcsd/crcnetd/_utils/
	install -m644 -o pcs -g pcs dbschema/* \
		$(DESTDIR)/usr/share/pcsd/dbschema/
	install -d -m755 -o pcs -g pcs $(DESTDIR)/usr/share/doc/pcsd/
	install -m644 -o pcs -g pcs docs/* $(DESTDIR)/usr/share/doc/pcsd/
	install -d -m755 -o pcs -g pcs $(DESTDIR)/usr/sbin/
	install -m755 -o pcs -g pcs pcsd $(DESTDIR)/usr/sbin/pcsd

uninstall:
	rm -rf /usr/sbin/pcsd /usr/share/pcsd/ /usr/share/doc/pcsd/

clean:
	@rm -f pcsd-r*.tar.{bz2,gz}
	@find . -name \*.pyc -exec rm {} \;

# Build release tarballs
release: clean
	@rm -f $(tmpdir)
	@mkdir -p $(tmpdir)
	@svn export . $(tmpdir)/pcsd-r$(r)
	@sed 's/pcsd_revision=".*"/pcsd_revision="$(r)"/' < \
		$(tmpdir)/pcsd-r$(r)/crcnetd/version.py > \
		$(tmpdir)/pcsd-r$(r)/crcnetd/version.py.$$
	@mv $(tmpdir)/pcsd-r$(r)/crcnetd/version.py.$$ \
		$(tmpdir)/pcsd-r$(r)/crcnetd/version.py
	@cd $(tmpdir); tar cjf $(pwd)/pcsd-r$(r).tar.bz2 pcsd-r$(r)/
	@cd $(tmpdir); tar czf $(pwd)/pcsd-r$(r).tar.gz pcsd-r$(r)/
	@rm -rf $(tmpdir)

.PHONY: clean release install-server install-client
