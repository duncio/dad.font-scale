import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One bar button / popup controlling three font sizes independently:
//   • terminal (foot) point size
//   • GTK apps' effective text size (via org.gnome.desktop.interface text-scaling-factor)
//   • the Omarchy shell's font base-size (the rem root for the whole bar)
// Backed by scripts/font-size; live values are re-read whenever the panel opens.

Panel {
  id: root
  moduleName: "dad.font-scale"
  ipcTarget: "dad.font-scale"

  implicitWidth: bar ? (bar.vertical ? bar.barSize : button.implicitWidth) : button.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  property int terminalPt: 11
  property int gtkPt: 11
  property int shellPx: 12

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string scriptDir: pluginDir + "/scripts"

  Component.onCompleted: {
    if (!stateProc.running) stateProc.running = true
  }

  onOpenedChanged: {
    if (root.opened && !stateProc.running) stateProc.running = true
  }

  // ── State refresh ──────────────────────────────────────────────────────────
  Process {
    id: stateProc
    command: ["bash", "-c", "export PATH=\"" + root.scriptDir + ":$HOME/.local/bin:$PATH\"; font-size get 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var l = lines[i].trim()
          if (l.indexOf("TERMINAL_PT=") === 0) root.terminalPt = parseInt(l.substring(12), 10) || root.terminalPt
          else if (l.indexOf("GTK_PT=") === 0) root.gtkPt = parseInt(l.substring(7), 10) || root.gtkPt
          else if (l.indexOf("SHELL_PX=") === 0) root.shellPx = parseInt(l.substring(9), 10) || root.shellPx
        }
      }
    }
  }

  // ── Command execution (single slot + one pending) ─────────────────────────
  property string pendingCmd: ""

  Process {
    id: execProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.pendingCmd !== "") {
          var cmd = root.pendingCmd
          root.pendingCmd = ""
          execProc.command = ["bash", "-c", cmd]
          execProc.running = true
        } else if (!stateProc.running) {
          stateProc.running = true
        }
      }
    }
  }

  function applyCommand(cmd) {
    var full = "export PATH=\"" + root.scriptDir + ":$HOME/.local/bin:$PATH\"; " + cmd
    if (!execProc.running) {
      execProc.command = ["bash", "-c", full]
      execProc.running = true
    } else {
      root.pendingCmd = full
    }
  }

  function setTerminal(pt) { root.terminalPt = pt; root.applyCommand("font-size terminal " + pt) }
  function setGtk(pt)      { root.gtkPt = pt;       root.applyCommand("font-size gtk " + pt) }
  function setShell(px)    { root.shellPx = px;     root.applyCommand("font-size shell " + px) }
  function resetAll()      { root.applyCommand("font-size reset-all") }

  // ── Bar button ─────────────────────────────────────────────────────────────
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Aa"
    active: root.opened
    tooltipText: "Font Size"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(Math.min(Style.space(560), stack.implicitHeight + Style.space(24)))

    Column {
      id: stack
      anchors.fill: parent
      spacing: Style.space(14)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Aa"
          font.pixelSize: Style.font.title
          color: Color.accent
          verticalAlignment: Text.AlignVCenter
        }

        Column {
          width: parent.width - Style.space(48)
          spacing: 1

          Text {
            text: "Font Size"
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.popups.text
          }

          Text {
            text: "Terminal · GTK apps · Shell"
            font.pixelSize: Style.font.caption
            color: Color.muted
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)
      }

      SizeRow {
        title: "Terminal"
        unitLabel: "pt"
        values: [8, 9, 10, 11, 12, 13, 14, 15, 16]
        current: root.terminalPt
        onPicked: function (v) { root.setTerminal(v) }
      }

      SizeRow {
        title: "GTK Apps"
        unitLabel: "pt"
        values: [9, 10, 11, 12, 13, 14, 15, 16, 18]
        current: root.gtkPt
        onPicked: function (v) { root.setGtk(v) }
      }

      SizeRow {
        title: "Shell"
        unitLabel: "px"
        values: [9, 10, 11, 12, 13, 14, 15, 16, 18, 20]
        current: root.shellPx
        onPicked: function (v) { root.setShell(v) }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)
      }

      Text {
        width: parent.width
        text: "Foot applies terminal size to new windows. GTK apps pick up changes on restart; the shell reflows live."
        font.pixelSize: Style.font.caption - 2
        wrapMode: Text.Wrap
        color: Color.muted
      }

      BorderSurface {
        width: parent.width
        height: Style.space(28)
        radius: Style.cornerRadius
        color: "transparent"
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Text {
          anchors.centerIn: parent
          text: "Reset all (11pt · 11pt · 12px)"
          font.pixelSize: Style.font.caption
          font.bold: true
          color: Color.popups.text
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.resetAll()
        }
      }
    }
  }

  // ── Reusable size selector row ─────────────────────────────────────────────
  component SizeRow: Item {
    id: sizeRow
    required property string title
    required property string unitLabel
    required property var values
    required property int current
    signal picked(int value)

    width: parent.width
    height: col.implicitHeight

    Column {
      id: col
      width: parent.width
      spacing: Style.space(6)

      Item {
        width: parent.width
        height: Style.space(16)

        Text {
          text: sizeRow.title
          font.pixelSize: Style.font.caption
          font.bold: true
          color: Color.popups.text
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: sizeRow.current + " " + sizeRow.unitLabel
          font.pixelSize: Style.font.caption
          font.bold: true
          color: Color.accent
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: sizeRow.values

          delegate: BorderSurface {
            width: (parent.width - Style.space(4 * (sizeRow.values.length - 1))) / sizeRow.values.length
            height: Style.space(26)
            radius: Style.cornerRadius
            color: sizeRow.current === modelData
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
              : "transparent"
            borderSpec: Border.controlSpec(
              sizeRow.current === modelData ? "selected" : "normal",
              Color.popups.text,
              Color.accent
            )

            Text {
              anchors.centerIn: parent
              text: modelData
              font.pixelSize: Style.font.caption
              color: sizeRow.current === modelData ? Color.accent : Color.popups.text
              font.bold: sizeRow.current === modelData
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: sizeRow.picked(parseInt(modelData, 10))
            }
          }
        }
      }
    }
  }
}