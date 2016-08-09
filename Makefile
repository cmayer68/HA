#
# makefile for HA script distro
# $Id: Makefile 3.0 2016-08-04 03:09:23 cmayer $
#
# Copyright 2016 AppDynamics, Inc
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

SHELL=/bin/bash

APPD_ROOT=/opt/AppDynamics/Controller

SRC_ROOT := $(shell pwd)
BUILDDIR := ../../build
EMBEDDER := ../../../tools/embed.pl
EMBED := perl $(EMBEDDER)

BASH_SRC= assassin.sh failover.sh watchdog.sh \
	watchdog.settings.template \
	replicate.sh install-init.sh uninstall-init.sh \
	appdservice-pbrun.sh appdservice-root.sh \
	appdservice-xuser.sh appdstatus.sh \
	appdynamics-machine-agent.sh appdynamics-machine-agent.sysconfig \
	mysqlclient.sh getaccess.sh \
	appdcontroller.sh appdcontroller-db.sh \
	appdcontroller.sysconfig appdcontroller-db.sysconfig \
	numa.settings.template numa-patch-controller.sh \
	save_mysql_passwd.sh rsyncd.conf \
	lib/password.sh lib/ha.sh lib/sql.sh lib/log.sh lib/conf.sh \
	lib/runuser.sh lib/init.sh \

C_SRC= appdservice.c

DIRS= lib monitors monitors/DiskMonitor monitors/MysqlMonitor

MONITORS= \
	monitors/DiskMonitor/monitor.xml monitors/DiskMonitor/disk-stat.sh \
	monitors/MysqlMonitor/monitor.xml monitors/MysqlMonitor/mysql-stat.sh \
	monitors/DiskMonitor/README monitors/MysqlMonitor/README

NOT_EMBEDDED= README RUNBOOK Release_Notes $(C_SRC) $(MONITORS)

BASH_SRC_EMBEDDED := $(addprefix $(BUILDDIR)/,$(BASH_SRC))

SOURCES= $(NOT_EMBEDDED) $(BASH_SRC_EMBEDDED)

all: publish

install:
	rm -f $(APPD_ROOT)/HA/*
	mkdir -p $(APPD_ROOT)/HA
	cp README *.sh $(APPD_ROOT)/HA
	sudo $(APPD_ROOT)/HA/install-init.sh

HA.shar: $(SOURCES) Makefile
	date +"# HA package built %c" > HA.shar
	echo "if echo '" >> HA.shar
	echo "' | od -b | grep -q 015 ; then echo dos format script - exiting ; exit 0 ; fi ; true" >> HA.shar
	cd $(BUILDDIR) && shar $(DIRS) $(BASH_SRC) | sed -e '/^exit/d' >> $(SRC_ROOT)/HA.shar
	shar $(NOT_EMBEDDED) | sed -e 's/^exit/chmod ugo+rx . .. ; find . -name \\*.sh -print | xargs chmod ugo+rx; exit/' >> HA.shar

$(BUILDDIR)/%: % $(EMBEDDER)
	$(EMBED) $< > $@

# ensure that $(BUILDDIR) is an 'order-only' dependency of $(SOURCES)
# so that a change in directory timestamp does not force rebuild of $(SOURCES)
$(SOURCES): | $(BUILDDIR)

$(BUILDDIR):
	mkdir $(BUILDDIR)
	(cd $(BUILDDIR) ; mkdir -p $(DIRS))

# useful debug aid. View variables on cmd line with:
#  make V="SOURCES BASH_SRC_EMBEDDED" debug
debug:
	$(foreach v,$(V),$(warning $v = $($v)))

# useful debug aid. View variables on cmd line with:
#  make print-SOURCES print-BASH_SRC_EMBEDDED
print-%:
	@echo '$*=$($*)'

#
# some common targets
#
publish: HA.shar

clean:
	rm -f appdservice
	rm -rf $(BUILDDIR)

clobber: clean
	rm -f HA.shar

#
# not used normally, as the install-init.sh compiles it in an installation
# here for development purposes.
#
appdservice: appdservice.c
	cc -DAPPDUSER=`id -u` -o appdservice appdservice.c
