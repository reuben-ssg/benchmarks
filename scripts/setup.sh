#!/bin/bash
# Generates the page sets and builds one project per tool and case under cases/.
# Usage: scripts/setup.sh [sizes...]   (default: 10 50 1000 10000)
set -euo pipefail
B=$(cd "$(dirname "$0")/.." && pwd)
cd "$B"
. scripts/tools.sh
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

node_link() { # case dir: point it at the shared install
  # Starlight fails to build (Vite leaves its modules external) unless the project has a package.json that lists it.
  cp tools/node/package.json "$1/package.json"
  ln -s "$NODE_TOOLS" "$1/node_modules"
}

eleventy_case() { # name set
  local d=cases/$1
  mkdir -p "$d/content/_includes"
  cp -R "sets/$2/content/." "$d/content/"
  cp -R "sets/$2/static" "$d/"
  printf '{ "layout": "layout.njk" }\n' > "$d/content/content.json"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ title }}</title></head><body><h1>{{ title }}</h1>\n{{ content | safe }}</body></html>\n' > "$d/content/_includes/layout.njk"
  # Eleventy has no code highlighting unless a plugin is added, and no footnotes unless markdown-it-footnote is.
  cat > "$d/eleventy.config.mjs" <<'JS'
import path from "node:path";
import footnote from "markdown-it-footnote";
export default function (eleventyConfig) {
  eleventyConfig.amendLibrary("md", (md) => md.use(footnote));
  eleventyConfig.addPassthroughCopy({ [path.join(import.meta.dirname, "static")]: "." });
  eleventyConfig.setUseGitIgnore(false);
  eleventyConfig.setQuietMode(true);
  return { markdownTemplateEngine: false, htmlTemplateEngine: false };
}
JS
  node_link "$d"
}

astro_case() { # name set
  local d=cases/$1
  mkdir -p "$d/src/pages"
  cp -R "sets/$2/content" "$d/content"
  cp -R "sets/$2/static" "$d/public"
  cat > "$d/astro.config.mjs" <<'JS'
import { defineConfig } from "astro/config";
export default defineConfig({
  site: "https://example.com",
  output: "static",
  devToolbar: { enabled: false },
  markdown: { syntaxHighlight: false },
});
JS
  cat > "$d/src/content.config.mjs" <<'JS'
import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
export const collections = { pages: defineCollection({ loader: glob({ pattern: "**/*.md", base: "./content" }) }) };
JS
  cat > "$d/src/pages/[...slug].astro" <<'ASTRO'
---
import { getCollection, render } from "astro:content";
export async function getStaticPaths() {
  const pages = await getCollection("pages");
  return pages.map((entry) => ({ params: { slug: entry.id === "index" ? undefined : entry.id }, props: { entry } }));
}
const { entry } = Astro.props;
const { Content } = await render(entry);
---
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{entry.data.title}</title></head><body><h1>{entry.data.title}</h1><Content /></body></html>
ASTRO
  node_link "$d"
}

starlight_case() { # name set
  local d=cases/$1
  mkdir -p "$d/src/content"
  cp -R "sets/$2/content" "$d/src/content/docs"
  cp -R "sets/$2/static" "$d/public"
  # Starlight keeps its defaults (theme CSS and JS, search index, expressive-code highlighting).
  # The one change is a one-link sidebar: the default sidebar lists every page on every page, which grows with the square of the page count.
  cat > "$d/astro.config.mjs" <<'JS'
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
export default defineConfig({
  site: "https://example.com",
  devToolbar: { enabled: false },
  integrations: [starlight({ title: "Bench", sidebar: [{ label: "Home", link: "/" }] })],
});
JS
  cat > "$d/src/content.config.mjs" <<'JS'
import { defineCollection } from "astro:content";
import { docsLoader } from "@astrojs/starlight/loaders";
import { docsSchema } from "@astrojs/starlight/schema";
export const collections = { docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }) };
JS
  node_link "$d"
}

jekyll_case() { # name set
  local d=cases/$1
  mkdir -p "$d/_layouts"
  cp -R "sets/$2/content/." "$d/"
  cp -R "sets/$2/static/." "$d/"
  printf 'title: Bench\nurl: https://example.com\npermalink: pretty\nplugins: []\nkramdown:\n  syntax_highlighter: nil\ndefaults:\n  - scope:\n      path: ""\n    values:\n      layout: default\n' > "$d/_config.yml"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ page.title }}</title></head><body><h1>{{ page.title }}</h1>\n{{ content }}</body></html>\n' > "$d/_layouts/default.html"
}

mdbook_case() { # name set
  local d=cases/$1
  node scripts/mdbook-src.mjs "sets/$2" "$d/src"
  mkdir -p "$d/theme"
  printf '[book]\ntitle = "Bench"\nsrc = "src"\n\n[output.html]\nsite-url = "/"\n\n[output.html.search]\nenable = false\n\n[output.html.print]\nenable = false\n' > "$d/book.toml"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{ title }}</title></head><body>\n{{{ content }}}</body></html>\n' > "$d/theme/index.hbs"
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
  # The other tools are optional: a missing one is skipped here and in run.sh.
  if have_eleventy; then eleventy_case "eleventy-bare-$N" "$N"; else skip_note eleventy "tools/node install"; fi
  if have_astro; then astro_case "astro-bare-$N" "$N"; else skip_note astro "tools/node install"; fi
  if have_starlight; then starlight_case "starlight-bare-$N" "$N"; else skip_note starlight "tools/node install"; fi
  if have_jekyll; then jekyll_case "jekyll-bare-$N" "$N"; else skip_note jekyll "jekyll"; fi
  if have_mdbook; then mdbook_case "mdbook-bare-$N" "$N"; else skip_note mdbook "mdbook"; fi
done
echo "cases ready: $(ls cases | wc -l | tr -d ' ')"
