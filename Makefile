PACKAGE = erlangxl
VERSION := \
	`./version.sh`
PV = $(PACKAGE)-$(VERSION)

SPECS = $(DESTDIR)/SPECS
SOURCES = $(DESTDIR)/SOURCES

SUBDIRS = \
	xl_stdlib \
	xl_json \
	xl_leveldb \
	xl_yaws \
	xl_csv \
	xl_io \
	xl_net \
	persist

SUBDIRS_CLEAN = $(patsubst %, %.clean, $(SUBDIRS))

.PHONY: clean all $(SUBDIRS) \
	rpm

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:	$(SUBDIRS_CLEAN)

$(SUBDIRS_CLEAN):
	$(MAKE) -C $(@:.clean=) clean

rpm:
	rm -rf $(PV)
	mkdir -p $(PV)
	for D in $(SUBDIRS); do \
		cp -a --parent $$D/Makefile $$D/src $(PV); \
		[ -d $$D/include ] && cp -a --parent $$D/include $(PV) || true; \
		[ -d $$D/priv    ] && cp -a --parent $$D/priv    $(PV) || true; \
		[ -d $$D/www     ] && cp -a --parent $$D/www     $(PV) || true; \
	done
	cp -a Makefile \
		Makefile.inc \
		*.spec.in \
		version.sh \
		$(PV)
	tar -czf $(SOURCES)/$(PV).tar.gz $(PV) && \
		rm -rf $(PV)
	sed "s,{{VERSION}},$(VERSION)," \
		$(PACKAGE).spec.in > $(SPECS)/$(PV).spec
	rpmbuild -ba $(SPECS)/$(PV).spec
