# facet · style-bloom

The bloom style: a thin rounded frame around every screen with the bar as its top edge, the
desktop a rounded hole in it, and panels that slide out of the frame and join it with soft
curves. Material You colors from the theme (or later from the wallpaper), Rubik and
Material Symbols, springy small things. It sits on [core](https://github.com/facet-shell/core),
which holds the services it shows; the login and boot screens still come from
[style-tui](https://github.com/facet-shell/style-tui) for now.

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
