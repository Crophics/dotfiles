# material-you-mocha (SDDM sign-in theme)

qylock's `material-you-dark` theme (Darkkal44 & Kaonaci, MIT, https://github.com/Darkkal44/qylock)
recolored to Catppuccin Mocha. SDDM runs before login and can't read ~, so the theme is installed as a copy:

    sudo cp -r ~/git/dotfiles/sddm/material-you-mocha /usr/share/sddm/themes/
    # /etc/sddm.conf.d/theme.conf:  [Theme]  Current=material-you-mocha

Not in git (see .gitignore):
- `font/` - Google Sans variable font; get it from qylock's themes/material-you-dark/font/
- `bg.png` - the background = a copy of the wallpaper (~/Pictures/Wallpapers/dark mountain.png)
  (`bg-mocha-blur.png` is the Catppuccin blur alternative; copy it over bg.png to use it)

Needs: sddm, qt6-declarative, qt6-5compat, qt6-svg.
