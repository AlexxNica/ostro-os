#
# Copyright (C) 2007 OpenedHand Ltd.
#

DESCRIPTION = "Gnome Mobile And Embedded Software Development Kit for OE-Core"
LICENSE = "MIT"
PR = "r12"

inherit packagegroup

require packagegroup-sdk-gmae.inc

PACKAGEGROUP_DISABLE_COMPLEMENTARY = "1"

RDEPENDS_${PN} = "\
    packagegroup-core-sdk \
    libglade-dev \
    ${SDK-GMAE} \
    ${SDK-EXTRAS}"
