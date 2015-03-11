# This file is part of Fork of crcnetd - CRCnet Configuration System Daemon
#
# Copyright (c) 2012 sun-exploit <a1@sun-exploit.com>
#
#  Fork of crcnetd is free software: you may copy, redistribute
#  and/or modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation, either version 2 of the
#  License, or (at your option) any later version.
#
#  This file is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This file incorporates work covered by the following copyright and
# permission notice:
#
#   Copyright (C) 2006  The University of Waikato
#
#   This file is part of crcnetd - CRCnet Configuration System Daemon
#
#   This file contains common code used throughout the system and extensions
#   - Constant values
#   - Small helper functions
#   - Base classes
#
#   Author:       Matt Brown <matt@crc.net.nz>
#   Version:      $Id$
#
#   crcnetd is free software; you can redistribute it and/or modify it under the
#   terms of the GNU General Public License version 2 as published by the Free
#   Software Foundation.
#
#   crcnetd is distributed in the hope that it will be useful, but WITHOUT ANY
#   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#   FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
#   details.
#
#   You should have received a copy of the GNU General Public License along with
#   crcnetd; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
import sys

from _utils.pcsd_log import *
from _utils.pcsd_config import config_init
from _utils.pcsd_daemon import *
from version import pcsd_version, pcsd_revision

from _utils.pcsd_server import startPCSDServer, stopPCSDServer, \
        processClassMethods, reactor
from _utils.pcsd_session import initSessions, pcsd_session
from _utils import pcsd_service
from _utils import pcsd_cfengine
from _utils import pcsd_ca

#####################################################################
# Bootstrapping
#####################################################################
def start():
    """Main entry point into the configuration daemon"""

    # Read configuration
    config_init()

    # Daemonise if necessary
    handleDaemonise()

    log_info("CRCnet Configuration System Daemon v%s (r%s)" % \
            (pcsd_version, pcsd_revision))

    # Initialise sessions
    initSessions()

    # Initialise modules
    modules = loadModules(PCSD_SERVER)
    for mod in modules:
        # Look for class methods to be registered with XMLRPC
        processClassMethods(mod)

    # Cfengine Configuration / Template System
    try:
        pcsd_cfengine.initCFengine()
    except:
        log_fatal("Failed to initialise CFengine integration!", sys.exc_info())

    # Initialise services
    processClassMethods(pcsd_service)

    # Initialise the certificate authority
    try:
        pcsd_ca.init_ca()
    except:
        log_fatal("Failed to initialise the CA!", sys.exc_info())

    # Call any module initialisation functions
    for mod in modules:
        if hasattr(mod, "pcs_init"):
            log_debug("%s::%s : pcs_init module=[%s]" % (__name__, 'start()', mod.__name__))
            mod.pcs_init()

    # Load the server key/cert from the certification authority
    ca = pcsd_ca.pcs_ca()
    key = None
    cert = None
    cacert = None
    try:
        key = ca.loadkey("server-key.pem")
    except:
        log_fatal("Unable to read server key!", sys.exc_info())
    try:
        cert = ca.loadcert("server-cert.pem")
    except pcs_ca_error:
        log_fatal("Unable to read server certificate!", sys.exc_info())

    # Load the ca cert(s) too
    try:
        cacert = ca.loadCACerts()
    except:
        log_fatal("CA certificate is not available!", sys.exc_info())
    del ca

    # Setup RPC Server - starts a mainloop via twisted.internet.reactor
    startPCSDServer(key, cert, cacert)

    # And that's it... We sit in the mainloop until we get a signal or something
    # to exit. Nothing more to do here.
