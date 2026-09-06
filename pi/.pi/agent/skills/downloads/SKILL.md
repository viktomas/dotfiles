---
name: downloads
description: Find the file I just downloaded or the screenshot I just took. Use whenever I say download, downloaded, downloads, screenshot or screenshots without naming a path.
---

# Downloads and screenshots

"the file I downloaded" / "the last screenshot" means the newest file in
`~/Downloads` or `~/Screenshots`. Never `ls` the whole directory — they are huge.

```sh
ls -t ~/Downloads | head -5
ls -t ~/Screenshots | head -5
```

Then act on the newest match. If the newest file is clearly not what I described
(wrong type, wrong bank, wrong columns), say so and ask — do not work around it.
