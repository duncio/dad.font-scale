# dad.font-scale

One bar button that sets three font sizes independently: your terminal, your GTK
apps, and the Omarchy shell itself.

## What it does

Omarchy has no single font-size control, and the three systems it draws text with
do not agree on units or on when they pick up a change. This plugin puts all
three behind one `Aa` button in the bar:

| Row        | Writes to                                             | Unit | Applies                     |
|------------|-------------------------------------------------------|------|-----------------------------|
| `Terminal` | `~/.config/foot/foot.ini` (`font=…:size=`)            | pt   | new foot windows            |
| `GTK Apps` | `gsettings org.gnome.desktop.interface text-scaling-factor` | pt effective | on app restart    |
| `Shell`    | `~/.config/omarchy/shell.toml` (`[font] base-size`)  | px   | immediately, live           |

Click `Aa` in the bar to open the panel. Each row is a strip of size buttons
with the current value highlighted in the accent colour. **Reset all** puts
everything back to 11pt · 11pt · 12px.

The footer in the panel says the same thing, because "nothing happened" is the
usual first question: foot needs a new window, GTK apps need a restart, and the
shell reflows on its own.

## Install

```bash
omarchy plugin add https://github.com/duncio/dad.font-scale
omarchy plugin enable dad.font-scale
```

Then move it where you want it:

```bash
omarchy bar move dad.font-scale --section left
```

## How GTK Apps works

GTK has no point-size setting. It has a base font (`font-name`, e.g. `Cantarell
11`) and a multiplier (`text-scaling-factor`, default `1.0`), and the size you
actually see is the product of the two.

So the panel shows and sets the **effective** size, and the plugin backs it into
a factor:

```
factor = wanted_pt / font_name_pt
```

Reading it back is the same arithmetic in reverse. The consequence worth knowing:
if a theme later changes your GTK base font, every GTK app gets bigger or smaller
and the plugin's stored number goes stale — it is corrected the next time the
panel is opened, since `get` re-reads the live values rather than trusting what
it wrote last time.

## How it works

```
Bar button (Aa)
  └── KeyboardPanel
        ├── SizeRow  Terminal  → font-size terminal <pt>
        ├── SizeRow  GTK Apps  → font-size gtk <pt>
        ├── SizeRow  Shell     → font-size shell <px>
        └── Reset all          → font-size reset-all
```

The QML owns no logic beyond layout. Every value comes from, and every change
goes through, `scripts/font-size`.

| File | Role |
|---|---|
| `manifest.json` | Registers the plugin; declares it a bar widget |
| `BarWidget.qml` | The `Aa` button, the panel, and the reusable `SizeRow` component |
| `scripts/font-size` | All reads and writes; the single source of truth |

The plugin runs commands through **one** `Process` with a single-slot queue: if
you click three sizes quickly, the last one wins rather than three processes
racing to write the same file. When the queue drains, state is re-read, so the
panel always reflects the files rather than an optimistic guess.

## CLI

The script is usable on its own, without the bar:

```bash
scripts/font-size get                  # prints TERMINAL_PT / GTK_PT / SHELL_PX
scripts/font-size terminal 13          # 8–20, clamped
scripts/font-size gtk 12
scripts/font-size shell 14
scripts/font-size reset-all            # 11 / 11 / 12
```

`get` re-syncs from the live sources (`foot.ini`, `gsettings`, `shell.toml`) and
then writes the state file, so it is a repair tool as much as a reader.

## Files it touches

| Path | What |
|---|---|
| `~/.config/foot/foot.ini` | `:size=` on the `font=` line; added if absent |
| `org.gnome.desktop.interface text-scaling-factor` | gsettings key |
| `~/.config/omarchy/shell.toml` | `[font] base-size`; the section is created if missing |
| `~/.local/state/omarchy/font-size/state.env` | Last known values |

`shell.toml` is rewritten via a temp file and `mv`, so a half-written config
cannot survive an interrupted change. After writing, the plugin also pushes the
theme and shell config through `omarchy-shell shell applyTheme`, so the bar
reflows without waiting for the file watcher.

## Troubleshooting

**The bar did not change size.** The shell reads `base-size` as the rem root for
every type size it draws. If the bar looks identical, confirm the value landed:

```bash
grep -A3 '\[font\]' ~/.config/omarchy/shell.toml
```

**Terminal size unchanged.** foot reads its config at startup and has no reload
signal. Open a new window; the plugin notifies you of this when foot is running.

**GTK apps unchanged.** They cache their scale at startup. Restart them.

**The panel shows a size that is not what you set.** Something else edited the
underlying file — a theme switch, or another tool. Reopening the panel re-reads
the live values, so the displayed number is the truth either way.

**`font-size` is not on PATH.** The panel prepends the plugin's `scripts/`
directory itself, so the bar always works. For manual use, call it by path or
add the directory to your `PATH`.