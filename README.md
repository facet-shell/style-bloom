<p align="center">
  <a href="https://github.com/facet-shell"><img src="https://raw.githubusercontent.com/facet-shell/.github/main/brand/mark.svg" alt="facet" width="64"></a>
</p>

<h3 align="center">style-bloom</h3>

<p align="center">The bloom style: a rounded frame with drawers that grow out of it.</p>

<p align="center"><sub><a href="https://github.com/facet-shell">facet</a> · <a href="https://github.com/facet-shell/core">core</a> · <a href="https://github.com/facet-shell/cli">cli</a> &nbsp;|&nbsp; <a href="https://github.com/facet-shell/style-tui">tui</a> · <b>bloom</b> &nbsp;|&nbsp; <a href="https://github.com/facet-shell/terminal">terminal</a> · <a href="https://github.com/facet-shell/spotify">spotify</a> · <a href="https://github.com/facet-shell/discord">discord</a> · <a href="https://github.com/facet-shell/steam">steam</a> · <a href="https://github.com/facet-shell/zed">zed</a> · <a href="https://github.com/facet-shell/zen">zen</a> · <a href="https://github.com/facet-shell/dolphin">dolphin</a> · <a href="https://github.com/facet-shell/keyboard">keyboard</a> &nbsp;|&nbsp; <a href="https://facet-shell.github.io">website</a> · <a href="https://github.com/orgs/facet-shell/projects/1">board</a></sub></p>

The bloom style: a thin rounded frame around every screen with the bar as its top edge, the
desktop a rounded hole in it, and panels that slide out of the frame and join it with soft
curves. Material You colors from the theme (or later from the wallpaper), Rubik and
Material Symbols, springy small things. It sits on [core](https://github.com/facet-shell/core),
which holds the services it shows, and brings its own login screen, boot splash and GRUB menu.

Part of [facet](https://github.com/facet-shell); fetch it and switch to it with the `facet`
command:

```bash
facet add style-bloom
facet style bloom
```

Files in the package folder are linked into your home with GNU Stow; the theme file comes from
`templates/` and is written by `facet theme` in the active theme. How the parts fit together
is in [CONTRACT.md](CONTRACT.md). Ideas and bugs:
[the board](https://github.com/orgs/facet-shell/projects/1).
