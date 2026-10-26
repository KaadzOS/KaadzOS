/* KaadzOS Calamares slideshow (generated from theme/palette). */

import QtQuick 2.5;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    textColor: "#e2e8f0"
    fontFamily: "Inter"

    Timer {
        interval: 12000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: background1
            source: "slide.png"
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.35
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.86
            horizontalAlignment: Text.Center
            wrapMode: Text.WordWrap
            color: "#e2e8f0"
            font.family: "Inter"
            font.pixelSize: 26
            font.bold: true
            text: qsTr("Installing KaadzOS")
        }
    }

    Slide {
        centeredText: qsTr("KaadzOS is copying the live system to disk, then\n" +
                           "removing live-only configuration and building a\n" +
                           "fresh initramfs for the installed kernel.")
    }

    Slide {
        centeredText: qsTr("The Night theme, Sway session and Waybar carry over\n" +
                           "unchanged. The installer removes itself on the first\n" +
                           "boot, leaving a clean installed system.")
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
