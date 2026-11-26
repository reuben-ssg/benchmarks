# Sourced by setup.sh and run.sh: which optional tools are installed.
# Node tools live in one shared install, tools/node/node_modules (see tools/node/package.json).
# Each case links to it instead of installing again, so no install ever happens inside a timed command.
NODE_TOOLS=$B/tools/node/node_modules
have_eleventy() { [ -x "$NODE_TOOLS/.bin/eleventy" ]; }
have_astro() { [ -x "$NODE_TOOLS/.bin/astro" ]; }
have_starlight() { [ -x "$NODE_TOOLS/.bin/astro" ] && [ -d "$NODE_TOOLS/@astrojs/starlight" ]; }
have_jekyll() { command -v jekyll > /dev/null 2>&1; }
have_mdbook() { command -v mdbook > /dev/null 2>&1; }
skip_note() { echo "skipping $1: $2 not found"; }
