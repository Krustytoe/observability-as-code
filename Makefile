SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

RULES      := $(wildcard prometheus/rules/*.yml)
RULE_TESTS := $(wildcard prometheus/tests/*.yml)
DASHBOARDS := $(wildcard grafana/dashboards/*.jsonnet)
JSONNET_SRC := $(DASHBOARDS) $(wildcard grafana/lib/*.libsonnet)
BUILD_DIR  := build/dashboards

.PHONY: ci vendor fmt fmt-check rules-check rules-test dashboards dashboards-check clean

## ci: everything CI runs, in order
ci: fmt-check rules-check rules-test dashboards dashboards-check

vendor: grafana/vendor
grafana/vendor: grafana/jsonnetfile.json
	cd grafana && jb install
	@touch $@

fmt:
	jsonnetfmt -i $(JSONNET_SRC)

fmt-check:
	jsonnetfmt --test $(JSONNET_SRC)

rules-check:
	promtool check rules $(RULES)

rules-test:
	promtool test rules $(RULE_TESTS)

dashboards: grafana/vendor
	@mkdir -p $(BUILD_DIR)
	@for f in $(DASHBOARDS); do \
	  out=$(BUILD_DIR)/$$(basename $${f%.jsonnet}).json; \
	  jsonnet -J grafana/vendor -o $$out $$f && echo "built $$out"; \
	done

dashboards-check: dashboards
	python3 scripts/check_dashboards.py $(BUILD_DIR)

clean:
	rm -rf build grafana/vendor
