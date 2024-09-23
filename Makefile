.DELETE_ON_ERROR:

SHELL:=bash

SRC:=src
LIB_SRC:=$(SRC)/lib
BIN_SRC:=$(SRC)/cli
DIST:=dist
QA:=qa

ALL_JS_FILES_SRC:=$(shell find $(SRC) -name "*.js" -o -name "*.cjs" -o -name "*.mjs")

BABEL_CONFIG_DIST:=$(DIST)/babel/babel-shared.config.cjs $(DIST)/babel/babel.config.cjs
BABEL_PKG:=$(shell npm explore @liquid-labs/sdlc-resource-babel-and-rollup -- pwd)

ROLLUP:=npx rollup
ROLLUP_CONFIG:=$(shell npm explore @liquid-labs/sdlc-resource-babel-and-rollup -- pwd)/dist/rollup/rollup.config.mjs

default: all

$(CONFIG_FILES_DIST): $(DIST)/%: $(LIB_SRC)/%
	mkdir -p $(dir $@)
	cp $< $@

$(BABEL_CONFIG_DIST): $(DIST)/babel/%: $(BABEL_PKG)/dist/babel/%
	mkdir -p $(dir $@)
	cp $< $@

FANDL_EXEC:=$(DIST)/fandl-exec.js
FANDL_EXEC_ENTRY:=$(SRC)/cli/index.mjs

$(FANDL_EXEC): package.json $(ALL_JS_FILES_SRC)
	JS_BUILD_TARGET=$(FANDL_EXEC_ENTRY) \
		JS_OUT=$@ \
		JS_FORMAT=cjs \
		JS_OUT_PREAMBLE='#!/usr/bin/env -S node --enable-source-maps' \
	  $(ROLLUP) --config $(ROLLUP_CONFIG)
	chmod a+x $@

JEST:=NODE_OPTIONS='$(NODE_OPTIONS) --experimental-vm-modules' NODE_NO_WARNINGS=1 npx jest
JEST_CONFIG:=$(shell npm explore @liquid-labs/sdlc-resource-jest -- pwd)/dist/jest.config.js
TEST_REPORT:=$(QA)/unit-test.txt
TEST_PASS_MARKER:=$(QA)/.unit-test.passed
COVERAGE_REPORTS:=$(QA)/coverage
BUILD_TARGETS:=$(CONFIG_FILES_DIST) $(BABEL_CONFIG_DIST) $(BIN_DIST)
PRECIOUS_TARGETS+=$(TEST_REPORT)

$(TEST_REPORT) $(TEST_PASS_MARKER) $(COVERAGE_REPORTS) &: package.json $(ALL_JS_FILES_SRC) $(FANDL_EXEC)
	mkdir -p $(dir $@)
	echo -n 'Test git rev: ' > $(TEST_REPORT)
	git rev-parse HEAD >> $(TEST_REPORT)
	( set -e; set -o pipefail; \
		SRJ_CWD_REL_PACKAGE_DIR=. \
		$(JEST) \
		--config=$(JEST_CONFIG) \
		$(TEST) 2>&1 \
		| tee -a $(TEST_REPORT); \
		touch $(TEST_PASS_MARKER) )
	rm -rf $(COVERAGE_REPORTS)
	mkdir -p $(COVERAGE_REPORTS)
	cp -r ./coverage/* $(COVERAGE_REPORTS)

# FANDL:=./dist/fandl.sh
LINT_REPORT:=$(QA)/lint.txt
LINT_PASS_MARKER:=$(QA)/.lint.passed
PRECIOUS_TARGETS+=$(LINT_REPORT)

$(LINT_REPORT) $(LINT_PASS_MARKER) &: $(ALL_JS_FILES_SRC) $(BUILD_TARGETS)
	mkdir -p $(dir $@)
	echo -n 'Test git rev: ' > $(LINT_REPORT)
	git rev-parse HEAD >> $(LINT_REPORT)
	( set -e; set -o pipefail; \
		$(FANDL) --check \
	    | tee -a $(LINT_REPORT); \
	  touch $(LINT_PASS_MARKER) )

lint-fix: $(ALL_JS_FILES_SRC) $(BUILD_TARGETS)
	@( set -e; set -o pipefail; \
	  $(FANDL) )

test: $(TEST_REPORT) $(TEST_PASS_MARKER)

lint: $(LINT_REPORT) $(LINT_PASS_MARKER)

qa: test lint

build: $(BABEL_CONFIG_DIST) $(FANDL_EXEC)

all: build

default: all

.PHONY: all build default lint qa

.PRECIOUS: $(LINT_REPORT)