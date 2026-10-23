# Diffs, callouts and foldables

Small fixture for the epub builder's smoke test.

## Callouts

> [!WARNING]
> One warning, its own box.

> [!TIP]
> - a list inside a callout
> - `inline code` works

> [!NOTE]+ Custom title
> A foldable callout is expanded for e-readers.

## Diff

```diff
--- a/config.yaml
+++ b/config.yaml
@@ -1,3 +1,3 @@
 server:
-  port: 8080
+  port: 9090
   host: localhost
```

## Details

<details>
<summary>Show the hidden paragraph</summary>

Hidden *markdown* and a list:

- a
- b

</details>

## SVG

```svg
<svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg"><rect x="5" y="5" width="190" height="70" fill="none" stroke="currentColor"/><text x="20" y="45" fill="currentColor">hello svg</text></svg>
```

## Links and entities

[local](./nope.sh) and a raw entity: &copy;.

## Überblick

Back to [the diff](#diff).
