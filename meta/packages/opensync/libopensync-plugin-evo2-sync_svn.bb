
SRC_URI = "svn://svn.opensync.org/plugins;module=evolution2;proto=http"
S = "${WORKDIR}/evolution2"

require libopensync-plugin.inc
require libopensync-plugin-svn.inc

DEPENDS += " eds-dbus"

DEFAULT_PREFERENCE = "-1"
