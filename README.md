# Sanguine

A dark, blood-and-gold Omarchy theme. Sanguine takes the [Miasma](https://omarchy.org/) theme as its base — keeping the wallpapers — and deviates from there into gothic maximalism: darker greys, oxblood reds, and deep antique gold.

## Install

```bash
omarchy theme install https://github.com/KRamPro/omarchy-sanguine-theme.git
```

That's it. The theme applies immediately.

### The companion hook (one extra step)

Sanguine ships a `theme-set.d` hook that gives Fastfetch a custom ASCII logo and safely coordinates the optional Sanguine Workspaces plugin. Omarchy themes cannot install hooks automatically. To enable the companion behavior:

```bash
omarchy plugin add https://github.com/KRamPro/omarchy-sanguine-workspaces.git
mkdir -p ~/.config/omarchy/hooks/theme-set.d
cp ~/.config/omarchy/themes/sanguine/hooks/fastfetch-theme-logo.sh \
   ~/.config/omarchy/hooks/theme-set.d/
chmod +x ~/.config/omarchy/hooks/theme-set.d/fastfetch-theme-logo.sh
omarchy theme set sanguine
```

The hook activates the custom look only while Sanguine is active. It snapshots the complete bar layout, the two workspace plugin states, and the pre-Sanguine inactive-window opacity; switching away restores those exact values.

## The companion integration, explained

Every time a theme is set, the hook:

1. **Resets fastfetch to pristine Omarchy defaults** by copying `/etc/fastfetch/config.jsonc` into `~/.config/fastfetch/`. Nothing custom ever accumulates.
2. **If the theme is `sanguine`**, swaps the logo `source` to `logo-ascii.txt` (the skull, in this repo) and tightens padding to `left: 1, right: 1` to reclaim columns for the wider art.
3. **If Sanguine Workspaces is installed**, replaces only the stock workspace widget with the companion and sets inactive-window opacity to 98%.
4. **When leaving Sanguine**, restores the complete pre-Sanguine bar layout, both plugin enable states, and the prior inactive-window opacity.

### Undo it

Switch to another theme first so the hook can restore the saved workspace layout and opacity, then remove it:

```bash
rm ~/.config/omarchy/hooks/theme-set.d/fastfetch-theme-logo.sh
rm ~/.config/fastfetch/config.jsonc
```

### Modify it

- **Different art**: edit `~/.config/omarchy/themes/sanguine/logo-ascii.txt` (or this repo's copy and reinstall). Plain text — any ASCII art works.
- **More breathing room**: the padding overrides are two `sed` lines at the bottom of the hook. Change `"right": 1` / `"left": 1` to taste, or delete the lines entirely for stock spacing.
- **Image logo instead**: foot supports Sixel. In the hook, add `"type": "sixel"` handling and point `source` at a `.jpg`/`.png`. Note that fastfetch caches rendered images under `~/.cache/fastfetch/` — clear that directory if you swap an image file's contents.

## Color choices

The palette in `colors.toml` is built around three ideas:

- **Blood red** (`#8c2f2f` accent, `#9b3535` red) — the signature. Oxblood rather than fire-engine: dark enough to sit on near-black without vibrating.
- **Deep antique gold** (`#a8873c` yellow, `#b3924a` cyan-as-gold-leaf) — the counterweight. Gold does the highlighting work that most themes give to blue or green.
- **Darker greys than Miasma** (`#1a1a1c` background down to `#0d0d0f`) — the stage. Warm parchment foreground (`#c9c3b8`) instead of pure white so text reads like ink on aged paper rather than a terminal.

The supporting cast stays deliberately subdued: graveyard-moss green and twilight violet are desaturated so red and gold always own the screen. Wine (`#a34258`) and dried blood (`#43291f`) round out the reds for syntax variety.

Tweak freely in `colors.toml`, then re-apply with `omarchy theme set sanguine`.

## Having trouble?

We'd genuinely rather you succeed the easy way: if anything here misbehaves, just point your AI agent at this repository and let it read the hook and configs directly. Everything is small, plain, and self-documenting — it should sort you out in one pass.
