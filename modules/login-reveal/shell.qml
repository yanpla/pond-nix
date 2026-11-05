// Pond's unlock reveal, played once when the session starts.
//
// Pond's greeter ends its exit animation by going transparent, expecting a
// desktop underneath (like unlocking does), but at login the session only
// starts after the greeter is gone, so niri's empty backdrop showed. This
// covers every screen in the lock colour from the first frame, waits until
// the shell's wallpaper is up on all of them, and then reveals the desktop
// with the lockscreen's own DesktopCover/ExitTransition (the quadrant reveal
// used when unlocking).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "frontend" as Frontend

ShellRoot {
    id: root

    property bool revealing: false

    function reveal() {
        if (revealing)
            return;
        revealing = true;
        settle.start();
    }

    Frontend.ExitTransition {
        id: exit
        onFinished: Qt.quit()
    }

    // The wallpaper surface exists a moment before it has drawn a frame.
    Timer { id: settle; interval: 150; onTriggered: exit.start() }
    // Never keep the desktop covered if the shell doesn't come up.
    Timer { interval: 8000; running: true; onTriggered: root.reveal() }

    Process {
        id: layers
        command: ["niri", "msg", "--json", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                let surfaces = [];
                try { surfaces = JSON.parse(text); } catch (e) { return; }
                const ready = surfaces.filter(l => l.namespace === "pond-wallpaper").map(l => l.output);
                if (Quickshell.screens.length > 0 && Quickshell.screens.every(s => ready.includes(s.name)))
                    root.reveal();
            }
        }
    }
    Timer {
        interval: 100
        repeat: true
        running: !root.revealing
        triggeredOnStart: true
        onTriggered: if (!layers.running) layers.running = true
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {} // clicks go through to the desktop
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pond-login-reveal"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Frontend.DesktopCover {
                anchors.fill: parent
                exitTransition: exit
                coverColor: "#1a1409" // the lockscreen's background colour
            }
        }
    }
}
