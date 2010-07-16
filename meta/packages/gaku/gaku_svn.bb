DESCRIPTION = "Music player"
LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://COPYING;md5=59530bdf33659b29e73d4adb9f9f6552 \
                    file://main.c;beginline=1;endline=20;md5=0c02b4ef945956832b37a036b9cc103a"
DEPENDS = "gtk+ gstreamer libowl-av"

RDEPENDS = "gst-plugins-base-audioconvert \
            gst-plugins-base-audioresample \
            gst-plugins-base-typefindfunctions \
            gst-plugins-base-playbin"

RRECOMMENDS = "gst-plugins-ugly-mad \
               gst-plugins-good-id3demux \
               gst-plugins-base-ivorbisdec \
               gst-plugins-base-alsa \
               gst-plugins-base-ogg"

PV = "0.0+svnr${SRCREV}"

PR = "r2"

SRC_URI = "svn://svn.o-hand.com/repos/misc/trunk;module=${PN};proto=http"

S = "${WORKDIR}/${PN}"

inherit autotools pkgconfig
