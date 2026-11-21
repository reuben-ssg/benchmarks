# Reuben vs Hugo (and Zola): build-speed benchmark, with and without checks

Run on 2026-11-19. Wall-clock time of one build invocation, measured with hyperfine.
Everything here is reproducible from `scripts/` (`setup.sh`, `run.sh`, `issues.sh`, `sizes.sh`, `summarize.mjs`).

## Headline (warm median, ms; ratio = tool / Reuben, so above 1 means Reuben is faster)

| Pages | Reuben, no a11y | Hugo, no checks | ratio | Zola, no checks | ratio | Reuben, as-is (a11y + links) | Hugo + lychee | ratio | Zola + lychee | ratio |
|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 22.7 | 38.4 | 1.69x | 36.2 | 1.59x | 22.9 | 50.0 | 2.18x | 51.0 | 2.23x |
| 50 | 33.7 | 42.0 | 1.25x | 43.6 | 1.29x | 33.1 | 67.5 | 2.04x | 64.0 | 1.93x |
| 1,000 | 195.0 | 157.0 | **0.81x (Hugo faster)** | 196.0 | 1.01x | 202.6 | 333.9 | 1.65x | 348.6 | 1.72x |

Plain reading of the numbers:

- Without checks, Hugo beats Reuben at 1,000 pages (157 vs 195 ms, Hugo about 20% faster) and Zola ties it (196 vs 195 ms).
  Reuben is faster only on the small sets, where it is mostly a lower fixed cost (a 10 to 15 ms start-up difference), not better per-page throughput.
- "As-is" Reuben is within 4% of Reuben with every accessibility rule off (22.9 vs 22.7, 33.1 vs 33.7, 202.6 vs 195.0 ms), so the a11y rules are cheap.
- Reuben's always-on checking (a11y plus link-target) is much cheaper than Hugo plus a separate lychee pass: lychee adds 12 ms (10 pages), 25 ms (50) and 177 ms (1,000) on top of Hugo, so the full "build and check links" pipeline is 1.65x to 2.2x slower than Reuben's default build.
  That comparison is not apples to apples (see asymmetries): Reuben's checks do more (a11y) and less (no anchor checking) than lychee.
- 1,000 pages is a hard case for Reuben relative to its own small-site speed: it takes about 195 ms, and Hugo's Go builds the same content in about 157 ms.

## Machine and environment

- Apple M3 Pro, 12 cores (6 performance and 6 efficiency, `hw.ncpu` = 12), 18 GiB RAM, macOS 27.2.1 (build 26B131, Darwin 27.2.0), APFS SSD.
- Normal desktop use throughout (other apps and a Claude Code session open, nothing closed). Load average at the start of the benchmark run: 3.69 3.11 2.99 (1/5/15 min); about 1.9 to 2.5 shortly before.
  Expect some noise; the spread in the table is small relative to the gaps except where noted.
- Reuben 0.1.1 release binary, real Mach-O arm64 binary behind the npm shim: `~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben` (invoked directly, no Node wrapper).
- Hugo v0.170.1+withdeploy darwin/arm64 (Homebrew), Zola 0.23.6 (Homebrew), lychee 0.24.2, hyperfine 2.0.0.
  Nothing was installed.

## Method

- Content: `scripts/gen.mjs` writes three sets (10, 50 and 1,000 pages) of identical Markdown, copied byte-for-byte into each tool's `content/` folder.
  Shape follows `reuben-core`'s `testsite::generate`, as in the earlier Astro benchmark: four collections (`guides`, `notes`, `posts`, `refs`), pages `p00000`..`pNNNNN`, front matter `title`, `description` and `weight`, 3 to 5 `##` sections each (emphasis, a list, an internal link to another page and an internal anchor link `#section-1` to it), inline math `$x^{i} + y$`, a footnote, a Rust code block and a 2-column table, plus a home page.
  Images: every tenth page has `![Bench logo](/img/logo.svg)` (with alt) and every page with `i % 10 == 7` has `![](/img/logo.svg)` (no alt) (1, 5 and 100 alt-less images in the 10, 50 and 1,000 sets).
  Seeded breakage in every set: 3 broken internal links (`/missing/nope-1/` to `-3/`, in pages 1 to 3) and 2 missing anchors (`/guides/p00000/#no-such-anchor-4` and `-5`, in pages 4 and 5).
  The previous benchmark's raw HTML card and Rhai bits were dropped, because Hugo and Zola would not render them the same way.
  Only the Markdown is identical: Hugo and Zola have a `_index.md` home (and Zola per-section `_index.md`); Reuben uses `index.md` and has no section index files.
- Layouts: Hugo and Zola use the same minimal hand-written layout (`baseof`/`single`/`list`, no theme): `<html lang>`, title, description (Hugo only), `<main>`, an `<h1>` and the content.
  Hugo disables taxonomy, term, RSS and sitemap output; Hugo still emits section list pages (1,005 HTML files for 1,000 pages). Zola emits its default sitemap, 404 and robots.
  Reuben uses its built-in theme (no theme folder), which adds CSS, navigation and a sitemap, so its output is larger (see sizes).
- Cases and commands (per set):
  - Reuben, as-is: `reuben build --root <dir>`; `reuben.toml` has only `title` and `base_url`. It always runs the a11y rules and link resolution and prints warnings.
  - Reuben, no a11y: same, plus `[a11y] disable = [...]` listing all 12 rule ids (`heading-order, link-text, img-alt, heading-id-unique, table-header, html-lang, page-title, single-h1, main-landmark, id-unique, form-label, link-target`; from `crates/reuben-a11y/src/rules.rs`, config key from `A11yConfig` in `crates/reuben-core/src/config.rs`). Confirmed: zero warnings are printed.
  - Hugo, no checks: `hugo --source <dir> --cacheDir <dir>` (output to `public/`, `--cacheDir` set explicitly).
  - Hugo, with checks: a 4-line `sh` script: the same hugo command, then `lychee --offline --include-fragments --index-files index.html --no-progress --root-dir <public> <public>`. The combined script is what is timed.
  - Zola, no checks: `zola --root <dir> build`. Zola, with checks: `zola build` then the same lychee line. Also timed: `zola check` alone (see below).
  - `--index-files index.html` is needed: without it lychee 0.24.2 cannot resolve a fragment on a directory-style URL (`/notes/p00005/#section-1`) and reports every anchor link as broken (29 false errors on the 10-page set).
- Timing: `hyperfine -N` (no shell) for single commands and for the `sh` scripts (a trivial `sh` script costs 2.6 ms, included in the combined cases), 2 warm-up runs then 10 measured runs, output directories deleted before every run (`--prepare`). Reported: median, mean ± σ, min, max of the 10 runs.
  "Warm" keeps Hugo's cache dir between runs (`hugocache-warm`); Hugo `resources/` and `public/` are deleted each run.
  "Cold": one run after deleting `dist`/`public`/`resources` and pointing Hugo's `--cacheDir` at a freshly removed dir. The OS file cache was not purged and the cold run is a single sample, so cold means "no tool caches", not a cold disk.
- Peak memory: one separate run under `/usr/bin/time -l` (maximum resident set size; for combined cases, the largest process in the pipeline).
- Output size: bytes of all files in `dist`/`public`; HTML files counted by `*.html`; JS bytes of `*.js`.
- Issues: Reuben's printed warnings counted by rule; lychee's errors counted from its output, run on each tool's output (including Reuben's `dist`, as a cross-check); `zola check` output.

## Build times (all cases)

| case | cold ms | median ms | mean ± σ | min | max | peak RSS MiB (time -l) |
|---|---|---|---|---|---|---|
| noop-shell | 29 | 2.6 | 2.7 ± 0.2 | 2.6 | 3.0 | 2 |
| hugo-checks-10 | 177 | 50.0 | 50.0 ± 0.4 | 49.5 | 50.8 | 70 |
| hugo-nochecks-10 | 148 | 38.4 | 38.1 ± 2.3 | 35.2 | 40.8 | 71 |
| reuben-checks-10 | 25 | 22.9 | 22.9 ± 0.2 | 22.6 | 23.3 | 33 |
| reuben-nochecks-10 | 24 | 22.7 | 22.6 ± 0.6 | 21.0 | 23.1 | 33 |
| zola-checkcmd-10 | 29 | 28.4 | 28.6 ± 0.3 | 28.3 | 29.1 | 64 |
| zola-checks-10 | 105 | 51.0 | 51.0 ± 0.9 | 49.5 | 52.3 | 67 |
| zola-nochecks-10 | 77 | 36.2 | 36.3 ± 0.5 | 35.8 | 37.2 | 67 |
| hugo-checks-50 | 110 | 67.5 | 67.4 ± 2.2 | 62.4 | 70.5 | 79 |
| hugo-nochecks-50 | 44 | 42.0 | 41.9 ± 1.0 | 40.4 | 43.9 | 77 |
| reuben-checks-50 | 37 | 33.1 | 33.4 ± 1.0 | 32.2 | 34.8 | 36 |
| reuben-nochecks-50 | 37 | 33.7 | 33.6 ± 0.9 | 32.1 | 34.9 | 36 |
| zola-checkcmd-50 | 30 | 29.6 | 29.7 ± 0.2 | 29.4 | 30.0 | 65 |
| zola-checks-50 | 120 | 64.0 | 63.9 ± 0.5 | 63.1 | 64.5 | 68 |
| zola-nochecks-50 | 46 | 43.6 | 43.5 ± 0.8 | 42.1 | 44.5 | 69 |
| hugo-checks-1000 | 383 | 333.9 | 334.5 ± 6.3 | 326.4 | 348.0 | 186 |
| hugo-nochecks-1000 | 199 | 157.0 | 158.4 ± 5.1 | 153.7 | 171.9 | 175 |
| reuben-checks-1000 | 255 | 202.6 | 202.9 ± 2.3 | 200.0 | 207.3 | 59 |
| reuben-nochecks-1000 | 248 | 195.0 | 195.9 ± 5.1 | 191.5 | 208.6 | 58 |
| zola-checkcmd-1000 | 56 | 55.2 | 55.1 ± 0.7 | 53.5 | 56.1 | 83 |
| zola-checks-1000 | 401 | 348.6 | 350.5 ± 3.6 | 347.0 | 357.0 | 91 |
| zola-nochecks-1000 | 201 | 196.0 | 197.0 ± 3.4 | 193.8 | 205.6 | 91 |

(Times in ms. Cold = single run. `zola-checkcmd` = `zola check` alone, which does not build.
`noop-shell` is the cost of the empty `sh` wrapper used by the combined cases: 2.6 ms.)

Per-tool deltas at the median (ms): lychee adds Hugo +11.6 / +25.5 / +176.9 (10 / 50 / 1,000 pages) and Zola +14.8 / +20.4 / +152.6; Reuben's a11y rules add about +0.2 / -0.6 / +7.6 (noise at the first two sizes).
Memory: Reuben 33 / 36 / 59 MiB, Hugo 71 / 77 / 175 MiB (186 MiB with lychee), Zola 67 / 69 / 91 MiB.

## Output size

Sizes are of the produced site (zola/hugo layouts are bare; Reuben ships a built-in theme and CSS, so the larger Reuben output is not a Markdown-rendering difference).
No tool emits any JavaScript.

| case | out bytes | HTML files | JS bytes |
|---|---|---|---|
| reuben-10 | 43762 | 11 | 0 |
| reuben-50 | 218264 | 51 | 0 |
| reuben-1000 | 4374319 | 1001 | 0 |
| hugo-10 | 28364 | 15 | 0 |
| hugo-50 | 138330 | 55 | 0 |
| hugo-1000 | 2760756 | 1005 | 0 |
| zola-10 | 25327 | 16 | 0 |
| zola-50 | 121989 | 56 | 0 |
| zola-1000 | 2427543 | 1006 | 0 |

## Issues reported (seeded: 3 broken links + 2 missing anchors per set)

Reuben (as-is) found all 3 broken internal links (rule `link-target`, a warning, exit status 0) and 0 of the 2 missing anchors: Reuben 0.1.1 only resolves anchors on its own `@/` links, and these sets use plain `/path/#anchor` links.
Its other findings are `img-alt` warnings for images without alt text: 1 / 5 / 100 for the 10 / 50 / 1,000 sets (which is exactly the number of alt-less images seeded). Reuben as-is prints 4 / 8 / 103 warnings total; with all rules disabled it prints 0 warnings and so also stops reporting the 3 broken links, because `link-target` is one of the 12 switchable rules.
(This corrects the task assumption that link checks can't be turned off in 0.1.1: the unresolved-link warning is switchable. The hard resolution of `@/` links, which these sets don't use, was not exercised.)

lychee (offline, with fragments) on the Hugo output, on the Zola output, and (cross-check) on Reuben's `dist`: 3 not-found links and 2 missing fragments each, 5 errors, in every set. So lychee found everything seeded; Reuben found 3 of 5 plus the a11y findings lychee cannot see.
`zola check` reported nothing on all three sets (0 of 5): it validates only `@/` internal links and external URLs, not plain `/path/` links, so it was not a usable comparison for these sets and was timed only as a footnote (28 / 30 / 55 ms).
Hugo has no built-in accessibility checking and none was added; Hugo "with checks" covers only links and anchors.

Full lychee and Reuben outputs: `results/issues-*.txt`, `results/issues.md`.

## Asymmetries and caveats (read before quoting any ratio)

- Not the same work. Reuben's "with checks" is a11y rules plus link-target warnings built into the render pass; Hugo's "with checks" is a separate full lychee pass over the HTML that also verifies anchors. Reuben's check does not verify anchors on plain links; lychee does not check accessibility. The `ratio` for "with checks" mixes these differences.
- "Without checks" for Reuben is not zero checking: front matter, template and `@/` link resolution errors still fire. The a11y rules (including link-target) are the part that was switched off.
- Hugo, Zola and Reuben render different output: Reuben renders the inline math to MathML and uses its built-in theme (nav, CSS, sitemap); Hugo and Zola output the `$...$` math as literal text and use a bare layout. Hugo and Zola's layouts are the minimal ones I wrote; real sites with themes, shortcodes, image processing or Sass would be slower on both. Code blocks are syntax highlighted by all three (Zola with `github-dark`, Hugo's default Chroma, Reuben's built-in).
- Reuben small-set times are dominated by what looks like a fixed ~15 to 20 ms start-up (22.9 ms at 10 pages and only +10 ms to 50 pages), probably syntax highlighting initialisation; not verified. The earlier Astro benchmark saw 8 ms on a code-free set.
- At 1,000 pages Hugo is faster than Reuben without checks (157 vs 195 ms); Zola equals it. Anyone claiming a build-speed advantage for Reuben over Hugo should restrict it to small sets or to pipelines that need a separate link checker.
- Hugo's page count is 1,001 pages plus section and list pages (1,005 HTML files); Reuben writes 1,001 (no section index pages) and Zola 1,006. Different page sets by design of each tool.
- Process-start overhead: hyperfine launches each Hugo/Zola/Reuben command directly (`-N`), but the combined cases include a 2.6 ms `sh`. At 10 pages that is 5% of the Hugo + lychee number.
- Cold runs are single samples and noisy (for example hugo-checks-10 cold 177 ms vs warm 50 ms; reuben cold 25 ms vs warm 23 ms).
- One machine, one OS, an interactive desktop under normal load (load average 2 to 4), 10 runs per case. Run-to-run spread was within 1 to 6% for most cases.
- Not measured: incremental/dev-server rebuilds, a theme-heavy site, parallelism scaling, anything on other hardware.

## Raw hyperfine output

(From `results/raw.txt`; paths are the scratch directory. The JSON exports are in `results/*.json`.)

```
=== reuben-checks-10 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-10 (1 run)
               Value
  Wall Time     24.8 ms
  Memory        32.9 MiB
 
=== reuben-checks-10 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-10 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     22.9 ms  ±     0.2 ms      22.6 ms  …    23.3 ms
  Memory        32.7 MiB ±     0.1 MiB     32.4 MiB …    32.8 MiB
 
            34144256  maximum resident set size
=== reuben-nochecks-10 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-10 (1 run)
               Value
  Wall Time     23.9 ms
  Memory        32.4 MiB
 
=== reuben-nochecks-10 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-10 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     22.6 ms  ±     0.6 ms      21.0 ms  …    23.1 ms
  Memory        32.6 MiB ±     0.2 MiB     32.2 MiB …    32.8 MiB
 
            34078720  maximum resident set size
=== hugo-nochecks-10 COLD ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-10 --cacheDir <scratch>/bench-hugo/hugocache-cold (1 run)
               Value
  Wall Time    147.6 ms
  Memory        70.7 MiB
 
=== hugo-nochecks-10 WARM ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-10 --cacheDir <scratch>/bench-hugo/hugocache-warm (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     38.1 ms  ±     2.3 ms      35.2 ms  …    40.8 ms
  Memory        70.3 MiB ±     0.3 MiB     69.8 MiB …    70.6 MiB
 
            74137600  maximum resident set size
=== hugo-checks-10 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-10-cold.sh (1 run)
               Value
  Wall Time    176.6 ms
  Memory        69.3 MiB
 
=== hugo-checks-10 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-10-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     50.0 ms  ±     0.4 ms      49.5 ms  …    50.8 ms
  Memory        70.5 MiB ±     0.6 MiB     69.7 MiB …    71.6 MiB
 
            73859072  maximum resident set size
=== zola-nochecks-10 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-10 build (1 run)
               Value
  Wall Time     76.9 ms
  Memory        66.7 MiB
 
=== zola-nochecks-10 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-10 build (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     36.3 ms  ±     0.5 ms      35.8 ms  …    37.2 ms
  Memory        66.6 MiB ±     0.1 MiB     66.5 MiB …    66.9 MiB
 
            69812224  maximum resident set size
=== zola-checks-10 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-10-cold.sh (1 run)
               Value
  Wall Time    104.8 ms
  Memory        66.4 MiB
 
=== zola-checks-10 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-10-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     51.0 ms  ±     0.9 ms      49.5 ms  …    52.3 ms
  Memory        66.6 MiB ±     0.2 MiB     66.4 MiB …    67.1 MiB
 
            69812224  maximum resident set size
=== zola-checkcmd-10 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-10 check (1 run)
               Value
  Wall Time     29.0 ms
  Memory        63.9 MiB
 
=== zola-checkcmd-10 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-10 check (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     28.6 ms  ±     0.3 ms      28.3 ms  …    29.1 ms
  Memory        64.0 MiB ±     0.1 MiB     63.9 MiB …    64.1 MiB
 
            67076096  maximum resident set size
=== reuben-checks-50 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-50 (1 run)
               Value
  Wall Time     36.9 ms
  Memory        36.0 MiB
 
=== reuben-checks-50 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-50 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     33.4 ms  ±     1.0 ms      32.2 ms  …    34.8 ms
  Memory        36.0 MiB ±     0.2 MiB     35.6 MiB …    36.3 MiB
 
            37912576  maximum resident set size
=== reuben-nochecks-50 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-50 (1 run)
               Value
  Wall Time     36.8 ms
  Memory        36.5 MiB
 
=== reuben-nochecks-50 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-50 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     33.6 ms  ±     0.9 ms      32.1 ms  …    34.9 ms
  Memory        36.1 MiB ±     0.2 MiB     35.8 MiB …    36.4 MiB
 
            38027264  maximum resident set size
=== hugo-nochecks-50 COLD ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-50 --cacheDir <scratch>/bench-hugo/hugocache-cold (1 run)
               Value
  Wall Time     44.5 ms
  Memory        77.6 MiB
 
=== hugo-nochecks-50 WARM ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-50 --cacheDir <scratch>/bench-hugo/hugocache-warm (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     41.9 ms  ±     1.0 ms      40.4 ms  …    43.9 ms
  Memory        77.4 MiB ±     0.6 MiB     76.4 MiB …    78.5 MiB
 
            80936960  maximum resident set size
=== hugo-checks-50 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-50-cold.sh (1 run)
               Value
  Wall Time    109.6 ms
  Memory        77.7 MiB
 
=== hugo-checks-50 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-50-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     67.4 ms  ±     2.2 ms      62.4 ms  …    70.5 ms
  Memory        77.8 MiB ±     0.6 MiB     76.3 MiB …    78.6 MiB
 
            82477056  maximum resident set size
=== zola-nochecks-50 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-50 build (1 run)
               Value
  Wall Time     46.2 ms
  Memory        68.3 MiB
 
=== zola-nochecks-50 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-50 build (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     43.5 ms  ±     0.8 ms      42.1 ms  …    44.5 ms
  Memory        68.6 MiB ±     0.2 MiB     68.1 MiB …    69.0 MiB
 
            72335360  maximum resident set size
=== zola-checks-50 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-50-cold.sh (1 run)
               Value
  Wall Time    119.5 ms
  Memory        68.6 MiB
 
=== zola-checks-50 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-50-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     63.9 ms  ±     0.5 ms      63.1 ms  …    64.5 ms
  Memory        68.6 MiB ±     0.2 MiB     68.3 MiB …    68.9 MiB
 
            71729152  maximum resident set size
=== zola-checkcmd-50 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-50 check (1 run)
               Value
  Wall Time     30.1 ms
  Memory        65.2 MiB
 
=== zola-checkcmd-50 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-50 check (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     29.7 ms  ±     0.2 ms      29.4 ms  …    30.0 ms
  Memory        65.2 MiB ±     0.1 MiB     65.0 MiB …    65.4 MiB
 
            68354048  maximum resident set size
=== reuben-checks-1000 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-1000 (1 run)
               Value
  Wall Time    255.4 ms
  Memory        58.6 MiB
 
=== reuben-checks-1000 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-1000 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    202.9 ms  ±     2.3 ms     200.0 ms  …   207.3 ms
  Memory        58.5 MiB ±     0.2 MiB     58.2 MiB …    59.0 MiB
 
            61636608  maximum resident set size
=== reuben-nochecks-1000 COLD ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-1000 (1 run)
               Value
  Wall Time    247.5 ms
  Memory        58.2 MiB
 
=== reuben-nochecks-1000 WARM ===
Benchmark 1: ~/git/reuben-ssg/docs/.worktrees/scaffold/node_modules/@reuben-ssg/reuben/node_modules/.bin_real/reuben build --root <scratch>/bench-hugo/cases/reuben-nochecks-1000 (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    195.9 ms  ±     5.1 ms     191.5 ms  …   208.6 ms
  Memory        58.1 MiB ±     0.2 MiB     57.6 MiB …    58.3 MiB
 
            60833792  maximum resident set size
=== hugo-nochecks-1000 COLD ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-1000 --cacheDir <scratch>/bench-hugo/hugocache-cold (1 run)
               Value
  Wall Time    199.1 ms
  Memory       177.6 MiB
 
=== hugo-nochecks-1000 WARM ===
Benchmark 1: hugo --source <scratch>/bench-hugo/cases/hugo-1000 --cacheDir <scratch>/bench-hugo/hugocache-warm (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    158.4 ms  ±     5.1 ms     153.7 ms  …   171.9 ms
  Memory       175.3 MiB ±     2.7 MiB    171.0 MiB …   180.4 MiB
 
           183779328  maximum resident set size
=== hugo-checks-1000 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-1000-cold.sh (1 run)
               Value
  Wall Time    383.3 ms
  Memory       183.8 MiB
 
=== hugo-checks-1000 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/hugo-checks-1000-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    334.5 ms  ±     6.3 ms     326.4 ms  …   348.0 ms
  Memory       174.3 MiB ±     5.0 MiB    166.6 MiB …   180.7 MiB
 
           194625536  maximum resident set size
=== zola-nochecks-1000 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-1000 build (1 run)
               Value
  Wall Time    200.9 ms
  Memory        90.8 MiB
 
=== zola-nochecks-1000 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-1000 build (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    197.0 ms  ±     3.4 ms     193.8 ms  …   205.6 ms
  Memory        90.9 MiB ±     0.3 MiB     90.5 MiB …    91.3 MiB
 
            95059968  maximum resident set size
=== zola-checks-1000 COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-1000-cold.sh (1 run)
               Value
  Wall Time    401.3 ms
  Memory        90.8 MiB
 
=== zola-checks-1000 WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/zola-checks-1000-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time    350.5 ms  ±     3.6 ms     347.0 ms  …   357.0 ms
  Memory        90.8 MiB ±     0.2 MiB     90.5 MiB …    91.2 MiB
 
            95567872  maximum resident set size
=== zola-checkcmd-1000 COLD ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-1000 check (1 run)
               Value
  Wall Time     56.1 ms
  Memory        83.5 MiB
 
=== zola-checkcmd-1000 WARM ===
Benchmark 1: zola --root <scratch>/bench-hugo/cases/zola-1000 check (10 runs)
                mean     ±       σ          min     …     max
  Wall Time     55.1 ms  ±     0.7 ms      53.5 ms  …    56.1 ms
  Memory        83.5 MiB ±     0.7 MiB     82.8 MiB …    84.8 MiB
 
            87474176  maximum resident set size
=== noop-shell COLD ===
Benchmark 1: <scratch>/bench-hugo/cmds/noop-shell-cold.sh (1 run)
               Value
  Wall Time     29.1 ms
  Memory         2.3 MiB
 
=== noop-shell WARM ===
Benchmark 1: <scratch>/bench-hugo/cmds/noop-shell-warm.sh (10 runs)
                mean     ±       σ          min     …     max
  Wall Time      2.7 ms  ±     0.2 ms       2.6 ms  …     3.0 ms
  Memory         2.3 MiB ±     0.0 MiB      2.2 MiB …     2.3 MiB
 
             2359296  maximum resident set size
DONE
```
