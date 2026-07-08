// Command mdreport renders a markdown file into a single HTML report.
//
// Three kinds of fenced code blocks get special treatment:
//
//    ```d2   -> compiled with the d2 library, inlined as SVG
//    ```svg  -> validated as well-formed SVG, inlined as-is
//    ```lang -> left as source text; highlight.js does the coloring client-side
//
// Everything else is standard CommonMark/GFM, rendered by goldmark's default
// renderer untouched.
//
// If any d2 or svg block fails validation, nothing is written or opened.
// Every error is printed with its block type and source line number, and
// the process exits 1.
package main

import (
	"bytes"
	"cmp"
	"context"
	"encoding/xml"
	"flag"
	"fmt"
	"html/template"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/renderer"
	"github.com/yuin/goldmark/util"

	"oss.terrastruct.com/d2/d2graph"
	"oss.terrastruct.com/d2/d2layouts/d2dagrelayout"
	"oss.terrastruct.com/d2/d2lib"
	"oss.terrastruct.com/d2/d2renderers/d2svg"
	"oss.terrastruct.com/d2/lib/log"
	"oss.terrastruct.com/d2/lib/textmeasure"
)

type buildError struct {
	kind    string
	line    int
	message string
}

// blockRenderer takes over rendering of ALL fenced code blocks so it can
// special-case "d2" and "svg". Everything else falls back to the same
// <pre><code class="language-x"> shape goldmark would have produced anyway.
type blockRenderer struct {
	errors *[]buildError
	ruler  *textmeasure.Ruler
}

func (r *blockRenderer) RegisterFuncs(reg renderer.NodeRendererFuncRegisterer) {
	reg.Register(ast.KindFencedCodeBlock, r.render)
}

func (r *blockRenderer) render(w util.BufWriter, source []byte, node ast.Node, entering bool) (ast.WalkStatus, error) {
	if !entering {
		return ast.WalkContinue, nil
	}
	n := node.(*ast.FencedCodeBlock)
	lang := strings.ToLower(string(n.Language(source)))

	var buf bytes.Buffer
	for i := 0; i < n.Lines().Len(); i++ {
		seg := n.Lines().At(i)
		buf.Write(seg.Value(source))
	}
	content := buf.String()

	line := 1
	if n.Lines().Len() > 0 {
		line = bytes.Count(source[:n.Lines().At(0).Start], []byte("\n")) + 1
	}

	switch lang {
	case "d2":
		svg, err := renderD2(content, r.ruler)
		if err != nil {
			*r.errors = append(*r.errors, buildError{"d2", line, err.Error()})
			return ast.WalkContinue, nil
		}
		_, _ = w.WriteString(`<figure class="diagram">`)
		_, _ = w.WriteString(svg)
		_, _ = w.WriteString(`</figure>`)

	case "svg":
		if err := validateSVG(content); err != nil {
			*r.errors = append(*r.errors, buildError{"svg", line, err.Error()})
			return ast.WalkContinue, nil
		}
		_, _ = w.WriteString(`<figure class="diagram">`)
		_, _ = w.WriteString(content)
		_, _ = w.WriteString(`</figure>`)

	default:
		_, _ = w.WriteString(`<pre><code class="language-`)
		_, _ = w.WriteString(template.HTMLEscapeString(lang))
		_, _ = w.WriteString(`">`)
		_, _ = w.WriteString(template.HTMLEscapeString(content))
		_, _ = w.WriteString(`</code></pre>`)
	}
	return ast.WalkContinue, nil
}

var xmlDeclRE = regexp.MustCompile(`^\s*<\?xml[^>]*\?>\s*`)

// renderD2 compiles a d2 script to SVG using d2 as a library (no CLI, no
// temp files, no subprocess). Layout/theme/etc are left at their defaults.
func renderD2(script string, ruler *textmeasure.Ruler) (string, error) {
	ctx := log.WithDefault(context.Background())
	compileOpts := &d2lib.CompileOptions{
		Ruler: ruler,
		LayoutResolver: func(engine string) (d2graph.LayoutGraph, error) {
			return d2dagrelayout.DefaultLayout, nil
		},
	}
	renderOpts := &d2svg.RenderOpts{}

	diagram, _, err := d2lib.Compile(ctx, script, compileOpts, renderOpts)
	if err != nil {
		return "", err
	}
	out, err := d2svg.Render(diagram, renderOpts)
	if err != nil {
		return "", err
	}
	return xmlDeclRE.ReplaceAllString(string(out), ""), nil
}

// validateSVG checks the block is well-formed XML with an <svg> root. It does
// NOT sanitize: an SVG may still contain <script>/<foreignObject>, which will
// execute when the report is opened. This is acceptable only because the input
// markdown is author-controlled; it is not a security boundary.
func validateSVG(content string) error {
	dec := xml.NewDecoder(strings.NewReader(content))
	var root *xml.StartElement
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("not well-formed XML: %w", err)
		}
		if se, ok := tok.(xml.StartElement); ok && root == nil {
			se := se
			root = &se
		}
	}
	if root == nil {
		return fmt.Errorf("empty document")
	}
	if !strings.EqualFold(root.Name.Local, "svg") {
		return fmt.Errorf("root element is <%s>, expected <svg>", root.Name.Local)
	}
	return nil
}

var pageTemplate = template.Must(template.New("page").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 860px; margin: 3rem auto; padding: 0 1.5rem; }
  h1, h2, h3 { line-height: 1.25; }
  pre { border-radius: 8px; padding: 1rem; overflow-x: auto; }
  figure.diagram { margin: 2rem 0; text-align: center; }
  figure.diagram svg { max-width: 100%; height: auto; }
  code:not(pre code) { background: rgba(127,127,127,0.18); padding: 0.1em 0.35em; border-radius: 4px; }
  table { border-collapse: collapse; }
  th, td { border: 1px solid rgba(127,127,127,0.35); padding: 0.4em 0.8em; }
</style>
</head>
<body>
{{.Body}}
<script>hljs.highlightAll();</script>
</body>
</html>
`))

type pageData struct {
	Title string
	Body  template.HTML
}

var titleRE = regexp.MustCompile(`(?m)^#\s+(.+)$`)

func openInBrowser(path string) {
	abs, err := filepath.Abs(path)
	if err != nil {
		abs = path
	}
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", abs)
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", "", abs)
	default:
		cmd = exec.Command("xdg-open", abs)
	}
	if err := cmd.Start(); err != nil {
		fmt.Printf("(built ok, but could not launch a browser: %v)\n", err)
	}
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "usage: %s <report.md> [output.html]\n", os.Args[0])
	}
	flag.Parse()
	args := flag.Args()
	if len(args) < 1 {
		flag.Usage()
		os.Exit(2)
	}

	inputPath := args[0]
	outputPath := ""
	if len(args) > 1 {
		outputPath = args[1]
	} else {
		outputPath = strings.TrimSuffix(inputPath, filepath.Ext(inputPath)) + ".html"
	}

	source, err := os.ReadFile(inputPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}

	ruler, err := textmeasure.NewRuler()
	if err != nil {
		fmt.Fprintln(os.Stderr, "error initializing text measurer:", err)
		os.Exit(2)
	}

	var errs []buildError
	md := goldmark.New(
		goldmark.WithExtensions(extension.GFM),
		goldmark.WithRendererOptions(
			renderer.WithNodeRenderers(
				util.Prioritized(&blockRenderer{errors: &errs, ruler: ruler}, 100),
			),
		),
	)

	var body bytes.Buffer
	if err := md.Convert(source, &body); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}

	if len(errs) > 0 {
		fmt.Printf("BUILD FAILED: %d error(s) in %s\n\n", len(errs), inputPath)
		for _, e := range errs {
			fmt.Printf("[%s block, line %d]\n  %s\n\n", e.kind, e.line, e.message)
		}
		os.Exit(1)
	}

	title := strings.TrimSuffix(filepath.Base(inputPath), filepath.Ext(inputPath))
	if m := titleRE.FindSubmatch(source); m != nil {
		title = string(m[1])
	}

	f, err := os.Create(outputPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}
	execErr := pageTemplate.Execute(f, pageData{Title: title, Body: template.HTML(body.String())})
	closeErr := f.Close()
	if err := cmp.Or(execErr, closeErr); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}

	fmt.Println(outputPath)
	openInBrowser(outputPath)
}
