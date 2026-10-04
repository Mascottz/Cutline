SHELL := /usr/bin/env bash
CACHE_ROOT ?= $(HOME)/.cache/cutline
OPAM_ROOT ?= $(HOME)/.cache/opam
ELM_HOME ?= $(CACHE_ROOT)/elm-home
NPM_CACHE ?= $(CACHE_ROOT)/npm
export CUTLINE_CACHE := $(CACHE_ROOT)

OPAM_BIN := $(shell scripts/install-opam.sh)
ELM_BIN := $(shell scripts/install-elm.sh)
NODE_BIN := $(shell scripts/install-node.sh)
NPM_BIN := $(dir $(NODE_BIN))npm
export PATH := $(dir $(NODE_BIN)):$(PATH)

INPUT ?= streets.geojson
OUTPUT ?= network.cutline.json
GRAPH ?= network.cutline.json
PORT ?= 0

.PHONY: setup build web-build test demo import serve clean

setup:
	@printf 'I use Node %s\n' "$$($(NODE_BIN) --version)"
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" init --root="$(OPAM_ROOT)" --bare --disable-sandboxing --yes default-repository https://opam.ocaml.org
	@if ! OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" switch list --short | grep -qx cutline; then OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" switch create cutline ocaml-base-compiler.5.5.1 --yes; fi
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" install --root="$(OPAM_ROOT)" --switch=cutline --yes --deps-only --with-test --locked .
	@$(NPM_BIN) ci --cache "$(NPM_CACHE)" --no-audit --no-fund
	@ELM_HOME="$(ELM_HOME)" PATH="$(dir $(ELM_BIN)):$(PATH)" "$(ELM_BIN)" --version
	@$(MAKE) build web-build

build:
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune build @all

web-build:
	@mkdir -p web/static
	@cd web && ELM_HOME="$(ELM_HOME)" PATH="$(dir $(ELM_BIN)):$(PATH)" "$(ELM_BIN)" make src/Main.elm --output=static/main.js

test: build web-build
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune runtest
	@cd web && ELM_HOME="$(ELM_HOME)" PATH="$(dir $(ELM_BIN)):$(PATH)" ../node_modules/.bin/elm-test
	@$(NODE_BIN) --check web/static/boot.js
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- bash scripts/smoke-demo.sh

demo: build web-build
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune exec cutline -- demo --port "$(PORT)"

import: build
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune exec cutline -- import "$(INPUT)" --out "$(OUTPUT)"

serve: build web-build
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune exec cutline -- serve "$(GRAPH)" --port "$(PORT)"

clean:
	@OPAMROOT="$(OPAM_ROOT)" "$(OPAM_BIN)" exec --root="$(OPAM_ROOT)" --switch=cutline -- dune clean
	@rm -f web/static/main.js web/static/main.js.map
