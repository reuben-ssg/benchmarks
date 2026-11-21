# Making Reuben the leanest and fastest SSG: measurements and recommendations

Run on 2026-11-19 against Reuben 0.1.1, Hugo 0.170.1 and Zola 0.23.6, same Markdown as `../bench-hugo`.
Analysis and measurement only: nothing was committed, no git repo was edited and nothing was installed.
All experiments that change Reuben's code ran on a copy of the source in `patched/` (no `.git`), built into scratch target dirs.

## Headlines

- **Size:** at 1,000 pages Reuben's default output is 4.37 MB against Zola's 2.27 MB and Hugo's 2.61 MB with byte-identical bare shells.
  The rendered prose, headings and heading ids are byte-for-byte the same in all three tools (1,437 bytes on the sample page).
  The whole gap is markup, in this order: syntax-highlight spans (+1.42 MB vs Zola), the built-in shell with inline CSS (+0.27 MB), footnote attributes (+0.16 MB), MathML (+0.19 MB) and the sitemap (+0.06 MB).
  One 54-byte Rust snippet becomes 2,049 bytes of `<span class="hl-meta hl-function hl-rust">` nesting in Reuben, against 793 in Hugo and 628 in Zola.
- **Math off (Nick's new default):** there is no switch today (`math_dollars = true` is hard-coded in `markdown.rs`).
  Writing the same formula as `\$…\$` produces output byte-identical to a build with math parsing turned off (verified with `diff -r` against a scratch build with `math_dollars = false`), so every "math off" number here is a real measurement, not a projection.
  It saves 186 bytes per page (185,890 bytes, 4.2% at 1,000 pages) and about 11 µs of CPU per page (0.9%); the wall-clock change is lost in noise.
- **Themes are currently a speed trap:** any layout file makes Reuben about twice as slow on small sites (44 to 54 ms instead of 23 ms at 10 pages) and 10 to 20% slower at 1,000 pages.
  Cause: Rhai 1.27's `sync` string interner, whose `locked_write` sleeps **10 ms** whenever two threads contend (`rhai/src/func/native.rs:693`, `std::thread::sleep(Duration::from_millis(10))`), hit on every per-page compile of a layout block.
  One line (`engine.set_max_strings_interned(0)` in `ScriptEngine::new`) brings a themed 10-page build from 53.4 to 25.6 ms, equal to the built-in shell (25.5 ms), measured interleaved.
- **Start-up:** 4.4 ms for the bare process, 6 to 7 ms for a one-page site without code, 20 to 22 ms with one code block (syntect's syntax set: about 14 ms and 10 MiB on first use; hypothesis confirmed).
- **Per page at 1,000:** Reuben already uses less CPU than Hugo (user + sys 690 ms vs 838 ms) but loses on wall clock (197 vs 156 ms) because reading the sources and writing the output are both single-threaded, which is about 70% of its wall time at 1,000 pages.
- **Memory:** Reuben is already the leanest: 57 to 59 MiB at 1,000 pages vs Hugo 175 and Zola 90; at 10,000 pages 243 MiB vs Hugo 964 and Zola 299.
  Syntect alone is 23 MiB of the 57 at 1,000 pages.

## Comparison table at 1,000 pages (quiet machine, AC power)

Built-in theme numbers include the 58 KB sitemap; slim and bare have the sitemap off, like the Hugo and Zola cases.

| case | output bytes | median ms | peak RSS MiB |
|---|---|---|---|
| Reuben built-in theme, math on (today's default) | 4,374,319 | 197.3 | 59 |
| Reuben built-in theme, math off | 4,188,429 | 208.7 | 58 |
| Reuben slim theme, math off | 4,011,856 | 235.7 | 60 |
| Reuben bare theme, math off, a11y off | 3,863,109 | 216.5 | 57 |
| Reuben bare theme, math off, a11y on | 3,863,109 | 248.8 | 58 |
| Hugo minimal layout (bench) | 2,760,756 | 155.5 | 175 |
| Hugo bare | 2,614,757 | 155.5 | 177 |
| Zola bare | 2,271,177 | 192.9 | 90 |
| **Projected:** Reuben bare + compact highlighting (rec. 2) | ≈2,108,000 | | |
| **Projected:** Reuben slim + compact highlighting | ≈2,257,000 | | |

The slim and bare Reuben rows are slower than the built-in theme only because of the Rhai interner sleep above (rec. 1), not because of anything the theme does.

## Machine, versions, conditions

- Apple M3 Pro (6P + 6E cores), 18 GiB, macOS 27.2.1, APFS.
- Reuben 0.1.1 shipped binary: `~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben`.
  Source: `~/git/nickvigilante/reuben/.worktrees/npm-scope` at `ec601f9` (the 0.1.1 bump), left untouched (`git status` clean before and after).
- Scratch builds: `target/dist/reuben` (same source, `dist` profile + debug info, for `sample`), `target/release/phases` (phase-timing harness linking `reuben-core`), `target-patched/dist/reuben` (copy of the source with env-var experiment toggles).
- hugo v0.170.1+withdeploy, zola 0.23.6, hyperfine 2.0.0, rustc 1.98.1.
- **Conditions changed mid-session.** The main table (`scripts/run.sh`) ran first, on a quiet machine (load 3 to 4), and reproduces `../bench-hugo` to within 2% (Reuben default 197.3 vs 195.0 ms, Hugo 155.5 vs 157.0 ms).
  Later the laptop went onto battery (43%, discharging) with a game running, and the same builds became 5 to 7 times slower.
  So the A/B experiment tables below are only good for **ratios between rows measured in the same interleaved hyperfine run**; their absolute milliseconds are not comparable with the main table.
  Peak RSS and output bytes are unaffected.

## Method

- `scripts/gen.mjs`: the bench-hugo generator, parameterised (`node gen.mjs <N> <dir> [--math-text|--no-code|--no-math|--empty]`).
  The 10 and 1,000 sets are byte-identical to `../bench-hugo/sets` (checked with `diff -r`).
  `--math-text` writes the formula as `\$x^{i} + y\$`, which renders exactly as math-off Reuben, Hugo and Zola do (literal `$x^{i} + y$`).
- `scripts/setup.sh` builds `cases/`.
  Reuben variants: `default` (built-in shell), `default-mathtext`, `slim`, `slim-math`, `bare` (a11y off), `bare-checks` (a11y on), `bare-math`, plus `bare-empty`, `bare-one-code`, `bare-one-nocode`, `bare-1000-nocode`.
  Hugo: `min` (the bench layout, unchanged) and `bare`; Zola: `bare`.
- Bare shell, identical in all three tools (Hugo `single.html`/`index.html`, Zola `page`/`index`/`section`, Reuben `themes/bare/layouts/default.html`):

  ```html
  <!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ page.title }}</title></head><body><h1>{{ page.title }}</h1>
  {{ content }}</body></html>
  ```

  Verified on output: the first 113 and last 15 bytes of every page are the same across tools.
  Hugo bare disables `section`, `404`, `robotsTXT`, `sitemap`, `RSS`, taxonomies (1,001 files); Zola bare sets `generate_sitemap = false`, `generate_robots_txt = false`, `render = false` on sections (1,002 files: Zola always writes `404.html`); Reuben `sitemap = false` (1,001 files).
- `scripts/run.sh`: `hyperfine -N --warmup 2 --runs 10 --prepare 'rm -rf <out>'`, then one `/usr/bin/time -l` run; `scripts/summarize.mjs` renders `results/table.md`.
- `scripts/breakdown.mjs`: byte breakdown of one page or a whole output dir, by regex on the HTML (shell, code block, math, footnotes, table, headings).
- `scripts/hl-slim.mjs`: prototype re-emission of Reuben's highlight spans to size recommendation 2.
- `phases/src/main.rs`: harness linking `reuben-core` read-only by path: `startup` (first-call costs), `phases` (load / render / write wall time), `micro` (serial per-stage cost over every page), `loop`, `layout`.
- `scripts/ab.sh`: interleaved hyperfine of the shipped binary against `target-patched/dist/reuben` with toggles `X_NOINTERN` (Rhai interner off), `X_PARLOAD` (parallel source reads), `X_PARWRITE` (parallel output writes), `X_NOMATH` (`math_dollars = false`), `X_NOHL` (no syntax highlighting).
- macOS `sample` on the debug-info binary: 40,000-page build (`profile/sample-bare-40000.txt`) and an in-process render loop of the bare 10-page site (`profile/sample-loop-bare10.txt`).

## 1. Output size breakdown

Representative page `notes/p00101/index.html` (5 sections, the Rust block, inline math, footnote, table), bytes:

| part | Reuben default | Reuben math off | Reuben bare | Hugo min | Hugo bare | Zola bare |
|---|---|---|---|---|---|---|
| **total** | **4,589** | **4,403** | **4,136** | **3,033** | **2,888** | **2,544** |
| shell before body (head, `<h1>`) | 371 | 371 | 113 | 251 | 113 | 113 |
| shell after body | 24 | 24 | 15 | 22 | 15 | 15 |
| prose, lists, links (rest) | 1,437 | 1,437 | 1,437 | 1,437 | 1,437 | 1,437 |
| of which `<h2>` headings | 165 | 165 | 165 | 165 | 165 | 165 |
| of which heading `id="…"` attrs | 75 | 75 | 75 | 75 | 75 | 75 |
| code block | 2,049 | 2,049 | 2,049 | 793 | 793 | 628 |
| of which the code's own text | 54 | 54 | 54 | 54 | 54 | 53 |
| inline math | 199 | 13 | 13 | 13 | 13 | 13 |
| footnote ref + section | 342 | 342 | 342 | 298 | 298 | 185 |
| table | 167 | 167 | 167 | 219 | 219 | 153 |
| newlines/tabs in the rest | 31 | 31 | 31 | 31 | 31 | 31 |

Whole 1,000-page sites (`results/breakdown-1000.md`), bytes:

| part | Reuben default | Reuben math off | Reuben slim | Reuben bare | Hugo min | Hugo bare | Zola bare |
|---|---|---|---|---|---|---|---|
| HTML total | 4,316,052 | 4,130,162 | 4,011,043 | 3,862,997 | 2,760,644 | 2,614,645 | 2,271,065 |
| shell (head + tail) | 395,077 | 395,077 | 275,958 | 127,912 | 273,959 | 127,960 | 127,980 |
| code blocks | 2,048,890 | 2,048,890 | 2,048,890 | 2,048,890 | 792,890 | 792,890 | 627,890 |
| math | 198,780 | 12,890 | 12,890 | 12,890 | 12,890 | 12,890 | 12,890 |
| footnotes | 341,890 | 341,890 | 341,890 | 341,890 | 297,890 | 297,890 | 184,890 |
| tables | 166,890 | 166,890 | 166,890 | 166,890 | 218,890 | 218,890 | 152,890 |
| non-HTML files | 58,267 (sitemap) | 58,267 | 813 (`s.css` + svg) | 112 | 112 | 112 | 112 |

Reuben default minus Zola bare = 2.10 MB, all accounted for: highlighting 1.421 MB (68%), shell 0.267 MB (13%), math 0.186 MB (9%), footnotes 0.157 MB (7%), sitemap 0.058 MB (3%), tables 0.014 MB.

What Reuben emits, and what is avoidable:

- **Highlighting** (`crates/reuben-core/src/highlight.rs`, `ClassedHTMLGenerator` with `ClassStyle::SpacedPrefixed { prefix: "hl-" }`): every syntect scope stack becomes nested spans, with every scope atom as a class and the language repeated in each (`hl-punctuation hl-section hl-parameters hl-begin hl-rust`), including `meta.*` and `source.*` wrapper scopes that themes almost never style.
  Worse, the built-in shell ships no CSS for these classes, so on a default site the 2 KB per block is pure dead weight.
  A prototype that keeps one short class per token (`k`, `s`, `n`, `f`, `c`) and unwraps `meta`, `source` and `punctuation` spans cuts the block from 2,049 to **294 bytes** (Hugo 793, Zola 628):

  ```html
  <pre><code class="language-rust"><span class="k">fn</span> <span class="f">main</span>() {
      <span class="k">let</span> n <span class="k">=</span> <span class="n">101</span>;
      <span class="f">println!</span>(<span class="s">&quot;<span class="n">{}</span>&quot;</span>, n);
  }
  </code></pre>
  ```

  Keeping the full classes but only unwrapping `meta`/`source` spans gives 1,207 bytes.
- **Built-in shell** (`crates/reuben-core/src/theme.rs`): 395 bytes per page vs 128 for the bare shell.
  The inline `<style>` (96 bytes of CSS plus tags) is repeated on every page, plus a newline after every head element and the viewport/description metas.
  The CSS is avoidable per page (one cached external file); the viewport meta is worth keeping.
- **Math** (`math.rs`, pulldown-latex): 199 bytes of MathML with a TeX `<annotation>` for a 13-byte formula.
  Avoidable by default per Nick's decision; when on, the annotation alone is about a third of it and could be optional.
- **Footnotes** (`html.rs::footnote_section`, `footnote_backref`): `data-footnotes`, `data-footnote-ref`, `data-footnote-backref`, `data-footnote-backref-idx` (GitHub's attributes, copied from comrak's output), plus `aria-label="Back to reference 1"`.
  The `data-*` attributes (about 90 bytes per footnote) are avoidable; keep the `aria-label`.
- **Headings with ids, prose, whitespace**: identical to Hugo and Zola; nothing to gain.
  Tables: Reuben's are already smaller than Hugo's (no tab indentation).
- **Sitemap**: 58 bytes per page, useful, keep (Hugo and Zola write one too by default; the bench disabled theirs).

## 2. Slim theme

`themes/slim/`: `layouts/default.html` (299 bytes) and `static/s.css` (467 bytes, under the 1 KB budget).

```html
<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{{ page.title }}</title><meta name="description" content="{{ page.description }}"><link rel="stylesheet" href="/s.css"><main><h1>{{ page.title }}</h1>
{{ content }}</main>
```

```css
:root{color-scheme:light dark}body{font:1rem/1.6 system-ui,sans-serif;max-width:70ch;margin:auto;padding:1rem}img{max-width:100%}pre{overflow:auto;padding:.75rem;background:#8881}code{font-size:.9em}table{border-collapse:collapse}th,td{border:1px solid #8886;padding:.25rem .5rem}:focus-visible{outline:2px solid}.hl-comment{color:#6a737d}.hl-string{color:#22863a}.hl-keyword,.hl-storage{color:#d73a49}.hl-constant{color:#005cc5}.hl-entity,.hl-support{color:#6f42c1}
```

- Valid HTML5 using the optional-tag rules (no `<head>`, `<body>` or closing `</html>`), with `lang`, charset, viewport, title, description, one cached stylesheet, a `<main>` landmark and one `<h1>`; it gives dark mode via `color-scheme`, a focus ring and highlight colours for the most common `hl-` classes.
  Reuben's own a11y rules pass it (the only warnings are the seeded broken links and alt-less images).
- Shell: 276 bytes per page vs Hugo's minimal layout at 274 and Reuben's built-in at 395.
- Total at 1,000 pages: 4,011,856 bytes (math off), **bigger than Hugo's minimal layout (2,760,756)**: the shell is already as small as Hugo's, but the highlight markup (+1,256 bytes per page vs Hugo) dominates.
  With compact highlighting (rec. 2) it projects to about 2.26 MB, 18% under Hugo's minimal layout and level with Zola's bare output.
- Time: 235.7 ms at 1,000 pages and 54 ms at 10 pages, vs 197 / 23 ms for the built-in shell; all of the difference is the Rhai interner sleep (see 4).

## 3. Bare theme, apples to apples

All rows use the identical bare shell above; Reuben has math off (Nick's default), the sitemap off, and the a11y rules off for the main row (Hugo and Zola check nothing).

| case | pages | output bytes | median ms | mean ± σ | min | max | peak RSS MiB |
|---|---|---|---|---|---|---|---|
| Reuben bare | 10 | 38,262 | 44.3 | 47.5 ± 11.1 | 37.1 | 64.9 | 33 |
| Reuben bare, a11y on | 10 | 38,262 | 52.8 | 51.2 ± 11.3 | 37.5 | 68.5 | 32 |
| Reuben bare, math on | 10 | 40,102 | 45.3 | 45.3 ± 12.9 | 22.6 | 68.2 | 33 |
| Hugo bare | 10 | 25,826 | 35.4 | 35.5 ± 0.4 | 35.0 | 36.5 | 70 |
| Zola bare | 10 | 22,410 | 36.4 | 36.4 ± 0.7 | 34.8 | 37.2 | 67 |
| Reuben bare | 50 | 192,404 | 60.3 | 61.4 ± 9.7 | 45.1 | 77.4 | 36 |
| Reuben bare, a11y on | 50 | 192,404 | 63.0 | 63.5 ± 10.7 | 47.6 | 79.4 | 36 |
| Reuben bare, math on | 50 | 201,644 | 60.6 | 63.4 ± 9.2 | 45.7 | 75.9 | 36 |
| Hugo bare | 50 | 130,032 | 40.7 | 40.9 ± 0.7 | 40.0 | 42.3 | 77 |
| Zola bare | 50 | 112,872 | 44.2 | 44.2 ± 0.9 | 42.8 | 45.3 | 68 |
| Reuben bare | 1,000 | 3,863,109 | 216.5 | 217.3 ± 6.8 | 209.9 | 232.9 | 57 |
| Reuben bare, a11y on | 1,000 | 3,863,109 | 248.8 | 252.9 ± 10.9 | 241.0 | 276.2 | 58 |
| Reuben bare, math on | 1,000 | 4,048,999 | 218.0 | 220.4 ± 7.1 | 212.5 | 231.0 | 57 |
| Hugo bare | 1,000 | 2,614,757 | 155.5 | 155.2 ± 0.7 | 153.9 | 155.8 | 177 |
| Zola bare | 1,000 | 2,271,177 | 192.9 | 192.8 ± 2.6 | 187.1 | 196.0 | 90 |

For reference, the built-in-shell Reuben (no layout file, so no Rhai) is 23.0 / 33.7 / 197.3 ms at 10 / 50 / 1,000 pages: faster than both rivals at 10 and 50 pages.
The bare layout turns that lead into a deficit, with ±11 ms jitter: that is the 10 ms interner sleep firing at random.
With the interner off, the bare 10-page build runs in 25.6 ± 1.8 ms (`results/nointern-10.txt`), back to built-in speed and 28% faster than Hugo or Zola.

The full per-case table (user/sys CPU, both RSS measurements, file counts) is `results/table.md`; raw hyperfine output is `results/<case>.txt` and `.json`, `/usr/bin/time -l` output `results/<case>.time`.

## 4. Where Reuben's time goes

### Fixed start-up cost

`results/startup.txt` (hyperfine, 3 warm-ups + 20 runs, shipped binary, battery conditions):

| site | median-ish wall (min) | peak RSS |
|---|---|---|
| `reuben --version` (process floor) | 4.4 ms (3.7) | 6.9 MiB |
| empty site (home page only), bare theme | 6.0 ms min (noisy median 16.9) | 12.5 MiB |
| one page, no code block | 6.9 ms (6.0) | 13.4 MiB |
| one page with one Rust block | 21.8 ms (19.6) | 23.2 MiB |
| bare 10 pages (for reference) | 47.2 ms (29.1) | 32.5 MiB |
| Hugo bare 10 pages (for reference) | 45.7 ms (38.5) | 69.6 MiB |

In process (`phases startup`, 3 runs): `ScriptEngine::new` 0.26 ms; the first `highlight()` call 10.5 ms (`SyntaxSet::load_defaults_newlines` deserialising all bundled syntaxes, plus compiling the first fancy-regex patterns), the second 0.4 ms; first `to_mathml` 0.03 ms; first comrak parse 0.03 ms.
So the syntect hypothesis holds: one code block costs about 14 ms of wall time and 10 MiB at start-up, which is two thirds of a small site's build.
Everything else (config, Rhai engine, walk, sitemap, atomic swap) fits in about 2 to 3 ms over the process floor.

### Per-page cost and phases

Wall-clock phases (`phases phases`, built-in shell, 1,000 pages, warm runs on the quiet machine; the first run of each case is a cold cache and is excluded):

| case | load | render | write | total |
|---|---|---|---|---|
| built-in, math on | 41 to 50 ms | 62 to 86 ms | 145 to 147 ms | 257 to 274 ms |
| built-in, math off | 40 to 41 ms | 61 to 64 ms | 99 to 139 ms | 203 to 241 ms |
| bare layout | 41 ms | 83 to 84 ms | 110 to 153 ms | 234 to 278 ms |

Only `render` is parallel (rayon).
`load` (`Site::load_with`, `site.rs`) reads and parses every file on one thread, and `write` (`output::stage`, `output.rs`) creates every directory and writes every file on one thread, after holding the whole site in memory.
Together they are 60 to 70% of the wall time at 1,000 pages, and at 40,000 pages `sample` shows the main thread spending 39% in serial `read`/`open` in `load_with` and 35% in serial `open`/`mkdir`/`write` in `write_atomic`, while the 12 render threads idle; the build is then superlinear (0.2 s at 1,000, 1.7 to 2.4 s at 10,000, 18.4 s at 40,000 pages).

Serial CPU per page, every stage timed separately over all 1,001 pages (`phases micro`, `profile/micro-1000.txt`; throttled CPU, so read the percentages):

| stage | built-in shell, µs/page | % | bare layout, µs/page | % |
|---|---|---|---|---|
| syntect highlighting (inside `html::render`) | 514 | 41.7 | 456 | 34.2 |
| rest of `html::render` | 60 | 4.9 | 102 | 7.7 |
| `check::html_pass` (html5ever re-tokenises the finished page) | 275 | 22.3 | 213 | 16.0 |
| comrak, 4 parses: `code_ranges` + `markdown::parse` at render, the same again in `precompute` at load | 303 | 24.6 | 298 | 22.4 |
| layout: read file + extract + Rhai compile and eval, per page | 4 (built-in) | 0.3 | 219 | 16.4 |
| `check::tree_pass` (a11y on / off) | 38 | 3.1 | 11 | 0.8 |
| `page::build_scope` (Rhai scope) | 18 | 1.4 | 21 | 1.6 |
| `math::render_math` (math on / off) | 11 | 0.9 | 1 | 0.1 |
| headings, links, block extraction | 10 | 0.8 | 10 | 0.8 |

Top hotspots, in order: syntax highlighting (35 to 42% of per-page CPU, plus 14 ms and 10 to 23 MiB of start-up and memory), file writes and reads (serial; most of the wall clock at 1,000+ pages), duplicate comrak parsing (about 25%), the html5ever re-scan (16 to 22%, which runs even with every a11y rule off because it also collects ids and links), and for themed sites the per-page layout compile plus the Rhai interner sleep.
Math, link resolution, heading ids, the a11y tree rules and the sitemap are each at or under 3%.

The interner, from `profile/sample-loop-bare10.txt` (render loop of the bare 10-page site): `render_layout` → `ScriptEngine::eval_block` → `Engine::compile` → `access_var` → `Engine::get_interned_string` → `nanosleep`, i.e. Rhai's `locked_write` backing off 10 ms on a contended `RwLock::try_write`.
In process, 40 back-to-back load+render passes of the bare 10-page site take a median 105 ms with the default rayon pool and 25 ms on one thread; the built-in shell takes 7 ms.

### A/B of candidate fixes (interleaved; ratios only)

`results/ab-summary-1.txt`, `results/ab-summary-2.txt`: median wall ms, min, user ms, peak RSS MiB; machine on battery and throttled, so compare rows within one case only.

| case | variant | median | min | user | RSS |
|---|---|---|---|---|---|
| bare-10 | shipped 0.1.1 | 223.4 | 193.6 | 96 | 32 |
| bare-10 | patched baseline | 229.9 | 194.3 | 98 | 32 |
| bare-10 | interner off | 125.8 | 104.0 | 124 | 32 |
| bare-10 | parallel load | 231.7 | 149.7 | 124 | 32 |
| bare-10 | parallel write | 210.8 | 109.7 | 105 | 32 |
| bare-10 | no highlighting | 153.1 | 137.3 | 25 | 14 |
| bare-10 | interner off + parallel load + write | 100.8 | 89.6 | 94 | 32 |
| bare-10 | all five (+ math off, no highlighting) | 44.1 | 33.4 | 27 | 14 |
| default-10 | shipped 0.1.1 | 106.5 | 91.8 | 92 | 32 |
| default-10 | no highlighting | 44.9 | 41.7 | 25 | 14 |
| default-10 | all five | 40.6 | 38.3 | 26 | 14 |
| bare-1000 | patched baseline | 1,375.9 | 1,299.8 | 1,580 | 56 |
| bare-1000 | interner off | 1,067.6 | 951.9 | 1,655 | 56 |
| bare-1000 | no highlighting | 1,014.6 | 959.4 | 695 | 32 |
| bare-1000 | interner off + parallel load + write | 794.8 | 592.8 | 1,523 | 56 |
| bare-1000 | all five | 557.7 | 488.4 | 809 | 33 |
| default-1000 | patched baseline | 1,278.6 | 1,137.5 | 1,855 | 57 |
| default-1000 | parallel load | 997.1 | 709.5 | 1,636 | 58 |
| default-1000 | parallel write | 887.3 | 762.1 | 1,561 | 58 |
| default-1000 | math off | 996.6 | 917.7 | 1,318 | 57 |
| default-1000 | no highlighting | 764.4 | 716.6 | 704 | 34 |
| default-1000 | interner off + parallel load + write | 734.9 | 617.9 | 1,806 | 58 |
| default-1000 | all five | 554.3 | 437.0 | 882 | 33 |

Reading: interner off removes 45% at 10 themed pages and 22% at 1,000; parallel load + write together with it remove 42 to 43% at 1,000 pages; dropping highlighting removes 62% of CPU and 40% of memory; all five together remove 57 to 60% at 1,000 pages.
The "math off" row on default-1000 is not trustworthy as a speed number (one noisy run; the serial micro-benchmark says math is under 1% of CPU).
Applied to the quiet-machine 197 ms, a 43% cut puts Reuben's 1,000-page build at roughly 110 to 120 ms against Hugo's 155 ms; that is a projection from ratios, not a measurement.

### Memory at 10,000 pages (`results/mem-10000.txt`, one `/usr/bin/time -l` run each)

| tool | wall (throttled) | peak RSS |
|---|---|---|
| Reuben 0.1.1 bare | 2.86 s | 243 MiB |
| Reuben, no highlighting | 1.72 s | 181 MiB |
| Reuben, interner off + parallel load + write | 1.50 s | 245 MiB |
| Hugo bare | 12.02 s | 964 MiB |
| Zola bare | 6.49 s | 299 MiB |

Reuben grows about 20 KB per page (57 MiB at 1,000, 243 at 10,000): every `Page` (source body, front matter), every rendered page's bytes in `Output`, and each page's id set and link list stay alive until the single write at the end.

## 5. Recommendations, ranked by impact vs effort

| # | change | where | expected gain (evidence) | effort | risk |
|---|---|---|---|---|---|
| 1 | Turn off Rhai's string interner, and compile each layout once per build | `script/mod.rs` `ScriptEngine::new`: `engine.set_max_strings_interned(0)`; `layout.rs` `render_layout`: cache the file text, `blocks::extract_all` result and compiled `AST`s per path (e.g. an `elsa::FrozenMap` already in deps) instead of reading and compiling per page | themed 10 pages 53 → 26 ms (measured, −52%); 1,000 pages −22% (A/B); layout stage 219 → ~5 µs/page; also removes the ±11 ms jitter; helps every `{{ }}` block in Markdown too | one line + a small cache | very low: interning only deduplicates strings; caching must key on path and keep per-page scope separate |
| 2 | Compact highlight markup by default, and no highlighting when the theme has no highlight CSS | `highlight.rs`: drive `syntect::parsing::ParseState` + `ScopeStack` yourself (or post-process `ClassedHTMLGenerator` output) mapping the innermost meaningful scope to one short class (`k s n f c v`), unwrapping `meta`/`source`/`punctuation` and merging runs; make `reuben css highlight` emit CSS for the short classes; config `[markdown] highlight = "compact" | "full" | "none"` | code block 2,049 → 294 bytes (prototype); −1.75 MB (−45%) of the bare 1,000-page site, making Reuben smaller than Zola (≈2.11 vs 2.27 MB) and Hugo (2.61 MB); `none` also saves 35 to 42% CPU, 14 ms start-up and 23 MiB | medium | medium: themes styling the long `hl-` classes break unless `full` stays available; class mapping needs care per language |
| 3 | Parallel I/O: read sources and write output on the rayon pool | `site.rs` `Site::load_with` (collect the walk, `par_iter` over `load_page`/`load_template`, merge in order; prototype in `patched/`); `output.rs` `stage` (create the unique parent dirs first, then `par_iter` the writes, collect every error) | −43% at 1,000 pages with rec. 1 (A/B), projecting ~110 to 120 ms vs Hugo 155; fixes the superlinear 10k to 40k curve | small (prototype is ~40 lines) | low: errors are still all collected, the atomic staging + swap is unchanged; ordering preserved by zipping |
| 4 | Make math opt-in (Nick's decision) | `config.rs`: add `[markdown] math = false` (new `MarkdownConfig` on `Raw`/`Config`); `markdown.rs` `options()` takes it (today `math_dollars = true` is hard-coded and `options()` is shared by `parse` and `code_ranges`, so both must get the flag); `page.rs` `render_body` skips `math::render_math` when off; consider `math.annotation = false` to drop the TeX annotation when on | −186 B/page, −185,890 bytes (−4.2%) at 1,000 pages (measured, output verified byte-identical); ~11 µs/page CPU (0.9%); keeps pulldown-latex off the hot path; `$` in prose is then always literal | small | low: sites with `$…$` must opt in; document it in the changelog |
| 5 | Stop parsing every page four times | `page.rs` `precompute` and `render_body`, `markdown.rs` `code_ranges`: skip `code_ranges` + `blocks::extract` when the body has no `{{` or `{%` (byte search); keep the load-time `Document` (and its heading ids) and reuse it at render for pages without blocks | ~20 to 25% of per-page CPU (3 of 4 comrak parses at ~75 to 80 µs each) | medium | low to medium: the toc-before-blocks and block-placeholder logic must stay exact; covered by existing tests |
| 6 | Don't re-tokenise the finished page with html5ever | `site.rs` `check_html` / `check.rs` `html_pass`: take ids and local links from the body `Document` (Reuben built it) and only scan the layout/raw-HTML parts, or skip the scan when every rule it serves is off and no anchor request targets the page | 16 to 22% of per-page CPU | medium | medium: the HTML-level rules (`html-lang`, `page-title`, `main-landmark`, `id-unique`) need the layout's markup, so scan that part only |
| 7 | Cheaper, smaller syntect when highlighting is on | `highlight.rs`: ship a custom syntax dump with the common languages and lazy-load the rest; or the `onig` regex backend instead of `regex-fancy` (faster matching, but a C dependency) | start-up 21.8 → ~7 ms for code pages (14 ms is syntect), −10 MiB; highlighting CPU down by an unmeasured factor with `onig` | medium | medium: binary size and portability (onig) |
| 8 | Lighter built-in shell | `theme.rs` `builtin_page`: write the CSS once as `/reuben.css` (or drop it) instead of an inline `<style>` on every page, drop the newlines between head elements; or adopt `themes/slim` as the built-in | 395 → ~250 B/page shell, −145 KB at 1,000 pages | small | low: users relying on the inline style see an extra request (cached) |
| 9 | Trim footnote markup | `html.rs` `footnote_section`, `footnote_backref`, `inline` (`FootnoteReference`): drop `data-footnotes`, `data-footnote-ref`, `data-footnote-backref`, `data-footnote-backref-idx`; keep `aria-label` | ~90 B per footnote, −~90 KB at 1,000 pages | small | low, but the test `table_footnote_and_strike_html_match_comrak` asserts comrak parity and would change |
| 10 | Stream pages to staging as they render | `site.rs` `render` + `output.rs`: write each page into the staging dir from the render worker, keep only its path in `Output.files` for the link check, then swap | peak memory roughly halves on large sites (rendered HTML is ~4.3 KB/page held until the end), and overlaps I/O with rendering | medium | medium: the in-memory `render` API used by `serve` and tests needs to stay; a failed build must still clean the staging dir |
| 11 | Build profile | workspace `Cargo.toml` `[profile.dist]`: try `lto = "fat"`, `codegen-units = 1`, `panic = "abort"` | typically 5 to 10%; **not measured here** | trivial | low; slower release builds |

What gets each goal:

- **(a) Lighter pages than Hugo/Zola by default:** recs 2 + 4 + 8 (+ 9).
  Bare output projects to about 2.1 MB vs Zola 2.27 and Hugo 2.61; with a styled default shell like `themes/slim` about 2.26 MB, still under Hugo's minimal layout (2.76 MB).
  Honest limit: on code-free, math-free, footnote-free prose all three tools emit the same bytes, so Reuben can only tie there; the win is entirely in markup Reuben controls.
- **(b) Faster start:** rec 1 (no 10 ms sleeps for themed sites), rec 2 `none` or rec 7 (syntect is 14 of the ~22 ms on a code page).
  Without code Reuben already starts in 6 to 7 ms against Hugo's ~35 ms and Zola's ~36 ms; the process floor is 4.4 ms, so there is little left beyond syntect.
- **(c) 1,000 pages faster than Hugo:** recs 1 + 3, then 5 and 6.
  Reuben already spends less CPU than Hugo (690 vs 838 ms user + sys); the loss is serial I/O, which rec 3 fixes, projecting ~110 to 120 ms vs 155 ms.
  At 10,000 pages Reuben already beats Hugo and Zola under the same (throttled) conditions (2.9 s vs 12.0 and 6.5 s).
- **(d) Less memory:** Reuben is already far below both (57 vs 175 and 90 MiB at 1,000 pages).
  Rec 2 `none` or 7 takes another 10 to 23 MiB off, rec 10 flattens the 20 KB/page growth.

## Files

- `scripts/`: `gen.mjs`, `patch.mjs` (adds `--math-text` to gen), `setup.sh`, `run.sh`, `summarize.mjs`, `breakdown.mjs`, `hl-slim.mjs`, `ab.sh`.
- `themes/slim/`, `themes/bare/`.
- `results/`: `table.md`, `summary.txt`, `<case>.{txt,json,time}`, `breakdown-1000.md`, `ab-*.{txt,json}`, `ab-summary-{1,2}.txt`, `startup.{txt,json}`, `nointern-10.txt`, `mem-10000.txt`.
- `profile/`: `startup.txt`, `phases.txt`, `micro-1000.txt`, `sample-bare-40000.txt`, `sample-loop-bare10.txt`, `b40k.log`.
- `phases/` (harness source), `patched/` (source copy with `X_*` toggles in `script/mod.rs`, `output.rs`, `site.rs`, `markdown.rs`, `html.rs`), `target/` and `target-patched/` (scratch builds, 2.8 GB; safe to delete).
