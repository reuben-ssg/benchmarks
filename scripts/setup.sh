#!/bin/bash
# Generates the page sets and builds one project per tool and case under cases/.
# Usage: scripts/setup.sh [sizes...]   (default: 10 50 1000 10000)
set -euo pipefail
B=$(cd "$(dirname "$0")/.." && pwd)
cd "$B"
SIZES=${*:-10 50 1000 10000}
mkdir -p cases sets

# Every a11y rule, for the "no checks" Reuben case.
OFF='[a11y]\ndisable = ["heading-order","link-text","img-alt","heading-id-unique","table-header","html-lang","page-title","single-h1","main-landmark","id-unique","form-label","link-target"]\n'

reuben_case() { # name set checks(on|off) [extra toml]
  local d=cases/$1
  mkdir -p "$d"
  cp -R "sets/$2/content" "sets/$2/static" "$d/"
  printf 'title = "Bench"\nbase_url = "https://example.com/"\ntheme = "%s"\nsitemap = false\n' "$B/themes/bare" > "$d/reuben.toml"
  [ "$3" = off ] && printf "\n$OFF" >> "$d/reuben.toml"
  [ -n "${4:-}" ] && printf '\n%b' "$4" >> "$d/reuben.toml"
  true
}

hugo_case() { # name set highlight(on|off)
  local d=cases/$1
  mkdir -p "$d/layouts/_default"
  cp -R "sets/$2/content" "sets/$2/static" "$d/"
  mv "$d/content/index.md" "$d/content/_index.md"
  printf 'baseURL = "https://example.com/"\ntitle = "Bench"\ndisableKinds = ["taxonomy","term","RSS","sitemap","section","404","robotsTXT"]\n' > "$d/hugo.toml"
  [ "$3" = off ] && printf '[markup.highlight]\ncodeFences = false\n' >> "$d/hugo.toml"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ .Title }}</title></head><body><h1>{{ .Title }}</h1>\n{{ .Content }}</body></html>\n' > "$d/layouts/_default/single.html"
  cp "$d/layouts/_default/single.html" "$d/layouts/index.html"
}

zola_case() { # name set highlight(on|off)
  local d=cases/$1
  mkdir -p "$d/templates"
  cp -R "sets/$2/content" "sets/$2/static" "$d/"
  mv "$d/content/index.md" "$d/content/_index.md"
  for c in guides notes posts refs; do
    [ -d "$d/content/$c" ] && printf '+++\nrender = false\n+++\n' > "$d/content/$c/_index.md"
  done
  printf 'base_url = "https://example.com"\ntitle = "Bench"\ncompile_sass = false\nbuild_search_index = false\ngenerate_sitemap = false\ngenerate_robots_txt = false\n' > "$d/config.toml"
  [ "$3" = on ] && printf '[markdown.highlighting]\ntheme = "github-dark"\n' >> "$d/config.toml"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ page.title }}</title></head><body><h1>{{ page.title }}</h1>\n{{ page.content | safe }}</body></html>\n' > "$d/templates/page.html"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ section.title }}</title></head><body><h1>{{ section.title }}</h1>\n{{ section.content | safe }}</body></html>\n' > "$d/templates/index.html"
  cp "$d/templates/index.html" "$d/templates/section.html"
}

for N in $SIZES; do
  rm -rf cases/*-"$N"
  # Hugo and Zola get `$x$` as plain text. Reuben gets `\$x\$`, which renders the same text whether or not
  # its math parsing is on, so every tool emits the same prose.
  node scripts/gen.mjs "$N" "sets/$N"
  node scripts/gen.mjs "$N" "sets/$N-mathtext" --math-text
  reuben_case "reuben-bare-$N" "$N-mathtext" off
  reuben_case "reuben-bare-noback-$N" "$N-mathtext" off '[markdown]\nfootnote_backlinks = false\n'
  reuben_case "reuben-bare-hash-$N" "$N-mathtext" off '[assets]\nhash = true\nheaders = true\n'
  reuben_case "reuben-bare-checks-$N" "$N-mathtext" on
  hugo_case "hugo-bare-$N" "$N" on
  hugo_case "hugo-nohl-$N" "$N" off
  zola_case "zola-bare-$N" "$N" on
  zola_case "zola-nohl-$N" "$N" off
done
echo "cases ready: $(ls cases | wc -l | tr -d ' ')"
