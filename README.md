# Recipes
by Patrick Cook

---

This is a growing collection of recipes for all sorts of foodstuffs. The idea behind this repo is to be a sort of defacto cookbook, focused around the LaTeX recipe template I ~~stole from StackExchange~~ created. Moreover, having all of these recipes in a repo makes sharing and storage redundancy easy.

If you'd like to write a recipe of your own in this format, feel free to use the `Template.tex` in the root directory, it should be well-commented.

---

To enable the git hook which automatically recompiles the recipe book before each push, simply run `git config --local core.hooksPath .githooks/` from within the repo.

---

To assemble a booklet, be sure to invoke `./compile.sh` with the `-b` option. To print, select double-sided (short-edge) and landscape.
