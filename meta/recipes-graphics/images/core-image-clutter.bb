DESCRIPTION = "An image with support for the Open GL-based toolkit Clutter, \
which enables development of rich and animated graphical user interfaces."

IMAGE_FEATURES += "apps-console-core package-management x11-base x11-sato ssh-server-dropbear"

LICENSE = "MIT"

IMAGE_INSTALL = "\
    ${CORE_IMAGE_BASE_INSTALL} \
    packagegroup-core-clutter-core \
    packagegroup-core-clutter-tests \
    packagegroup-core-clutter-apps"

inherit core-image
