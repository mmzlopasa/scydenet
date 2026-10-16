# Assets

| Asset | Source | License |
|---|---|---|
| Sora, Geist, Geist Mono, Doto (static TTF instances in `App/Resources/Fonts`) | Same font files as scyhost.com | SIL Open Font License 1.1 |
| App icon | Original SCYDE artwork generated for this project | Own |
| Extra text fonts (Georgia, Didot, Futura, Avenir, Marker Felt, Chalkduster, Snell Roundhand and others) | Fonts that ship with iOS, referenced by name, not bundled | Apple system fonts, rendered on device |
| Stickers | Emoji and SF Symbols drawn by the system at render time; no image files bundled | Apple system glyphs, rendered on device |
| Effects, masks, transitions, looks, text presets | Written in code with Core Image | Own |
| Template footage and music library | Wikimedia Commons files that are CC0, public domain or CC BY, chosen by hand in `scripts/media/curated.json` and built by `.github/workflows/media.yml` into the `template-media` release. Every item's title, author, licence and source page are in `manifest.json` and shown in the app. With a `PIXABAY_API_KEY` or `PEXELS_API_KEY` repository secret, footage comes from Pixabay (Pixabay Content License) or Pexels (Pexels License), credited per clip. Each clip has a JPEG poster | Per item, see manifest |
| Sound effects | Synthesised in code on the device (`SoundEffects.swift`) | Own |
