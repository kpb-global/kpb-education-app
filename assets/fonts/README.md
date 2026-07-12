# Bundled fonts

Typography from the App-engagement design handoff.

| Family | Weights | Use |
|---|---|---|
| Inter | 400 / 500 / 600 / 700 / 800 | Body & UI text (global `fontFamily`) |
| Plus Jakarta Sans | 600 / 700 / 800 | Headings (`KpbTextStyles`, screen titles) |

- Source: Google Fonts static TTFs (via google-webfonts-helper), subsets
  `latin` + `latin-ext` so French diacritics (é, à, ç, œ…) render correctly.
- License: SIL Open Font License 1.1.
  - Inter — Copyright 2016 The Inter Project Authors (https://github.com/rsms/inter)
  - Plus Jakarta Sans — Copyright 2020 The Plus Jakarta Sans Project Authors
    (https://github.com/tokotype/PlusJakartaSans)
- Bundled offline on purpose (no runtime font fetching): the app targets
  low-connectivity users.
