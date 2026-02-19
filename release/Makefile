SHELL := /usr/bin/env bash

RELEASE_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

JAM_PATH := $(RELEASE_ROOT)
JAMDUNA := $(RELEASE_ROOT)/jamduna
FIB_STREAM_RUNNER := $(RELEASE_ROOT)/fib-stream-runner
RUNNER_BIN_DIR_VISIBLE := $(RELEASE_ROOT)/runner
RUNNER_BIN_DIR_HIDDEN := $(RELEASE_ROOT)/.runner
RUNNER_BIN_DIR := $(if $(wildcard $(RUNNER_BIN_DIR_VISIBLE)/fib-builder),$(RUNNER_BIN_DIR_VISIBLE),$(if $(wildcard $(RUNNER_BIN_DIR_HIDDEN)/fib-builder),$(RUNNER_BIN_DIR_HIDDEN),$(RUNNER_BIN_DIR_VISIBLE)))
FIB_BUILDER := $(RUNNER_BIN_DIR)/fib-builder
FIB_FEEDER := $(RUNNER_BIN_DIR)/fib-feeder

DATA_PATH ?= $(RELEASE_ROOT)/state
LOGS_DIR ?= $(RELEASE_ROOT)/logs
PIDS_DIR ?= $(RELEASE_ROOT)/pids

CHAINSPEC_CONFIG ?= $(RELEASE_ROOT)/chainspecs/local-dev-config.json
CHAINSPEC ?= $(RELEASE_ROOT)/chainspecs/jamduna-spec.json
GENSPEC_JAM_PATH ?= $(abspath $(RELEASE_ROOT)/../..)
RELEASE_GENESIS_BUNDLE_DIR ?= $(RELEASE_ROOT)/release_genesis_services

PVM_BACKEND ?= compiler
VALIDATOR_COUNT ?= 6
VALIDATOR_MAX_INDEX := 5
BUILDER_INDEX ?= 6

RPC_BASE_PORT ?= 19800
P2P_BASE_PORT ?= 40000
FIB_STREAM_PID_FILE ?= $(PIDS_DIR)/fib-stream-runner.pid
FIB_STREAM_LOG ?= $(LOGS_DIR)/fib-stream-runner.log
ACTIVITY_TAIL_LINES ?= 200

.PHONY: help prepare quick-start check-bins gen-keys list-keys gen-spec run-v0 run-v1 run-v2 run-v3 run-v4 run-v5 run-validators run-fib-stream run-fib-stream-bg stop-fib health status stop clean-state

help:
	@echo "JAM DUNA local release flow (single machine, 6 validators)"
	@echo
	@echo "Targets:"
	@echo "  make prepare         # create logs/state/pids dirs"
	@echo "  make quick-start     # clean + keys + spec + validators (single-machine default)"
	@echo "  make gen-keys        # generate seed_0..seed_6 under state/keys"
	@echo "  make list-keys       # print validator key material"
	@echo "  make gen-spec        # generate chainspecs/jamduna-spec.json"
	@echo "  make run-validators  # start validator 0..5 in background"
	@echo "  make run-fib-stream  # run FIB flow in background (logs only)"
	@echo "  make run-fib-stream-bg # alias of run-fib-stream"
	@echo "  make stop-fib        # stop background fib-stream-runner"
	@echo "  make health          # check validator Imported Block activity"
	@echo "  make status          # show validator process status"
	@echo "  make stop            # stop validator 0..5"
	@echo "  make clean-state     # stop + wipe state data"
	@echo
	@echo "Important:"
	@echo "  - JAM_PATH is fixed to $(RELEASE_ROOT)"
	@echo "  - Builder/feeder binaries are stored under $(RUNNER_BIN_DIR_VISIBLE) (legacy .runner supported)"
	@echo "  - release genesis bundle path is $(RELEASE_GENESIS_BUNDLE_DIR)"
	@echo "  - seed_6 is reserved for optional builder role (not a validator process)"
	@echo "  - DATA_PATH is $(DATA_PATH)"
	@echo "  - CHAINSPEC is $(CHAINSPEC)"

check-bins:
	@test -x "$(JAMDUNA)" || (echo "Missing binary: $(JAMDUNA)" && exit 1)
	@test -x "$(FIB_STREAM_RUNNER)" || (echo "Missing binary: $(FIB_STREAM_RUNNER)" && exit 1)
	@test -x "$(FIB_BUILDER)" || (echo "Missing binary: $(FIB_BUILDER)" && exit 1)
	@test -x "$(FIB_FEEDER)" || (echo "Missing binary: $(FIB_FEEDER)" && exit 1)

prepare:
	@mkdir -p "$(LOGS_DIR)" "$(DATA_PATH)" "$(PIDS_DIR)" "$(RELEASE_ROOT)/chainspecs"

quick-start: clean-state gen-keys gen-spec run-validators
	@echo
	@echo "Quick start complete."
	@echo "Next:"
	@echo "  - check validator health: make health"
	@echo "  - optional FIB test: make run-fib-stream"

gen-keys: check-bins prepare
	@echo "Generating validator seeds at $(DATA_PATH)/keys ..."
	@JAM_PATH="$(JAM_PATH)" "$(JAMDUNA)" gen-keys --data-path "$(DATA_PATH)"

list-keys: check-bins
	@JAM_PATH="$(JAM_PATH)" "$(JAMDUNA)" list-keys --data-path "$(DATA_PATH)"

gen-spec: check-bins prepare
	@test -f "$(CHAINSPEC_CONFIG)" || (echo "Missing chain config: $(CHAINSPEC_CONFIG)" && exit 1)
	@echo "Generating chainspec from $(CHAINSPEC_CONFIG) ..."
	@if [[ -d "$(RELEASE_GENESIS_BUNDLE_DIR)" ]]; then \
		echo "Using release genesis bundle: $(RELEASE_GENESIS_BUNDLE_DIR)"; \
		JAM_GENESIS_USE_RELEASE_BUNDLE=1 JAM_PATH="$(RELEASE_ROOT)" "$(JAMDUNA)" gen-spec "$(CHAINSPEC_CONFIG)" "$(CHAINSPEC)"; \
	else \
		test -f "$(GENSPEC_JAM_PATH)/services/auth_copy/auth_copy.pvm" || (echo "Missing service assets at $(GENSPEC_JAM_PATH). Set GENSPEC_JAM_PATH=<full-jam-workspace>" && exit 1); \
		echo "Using full workspace: $(GENSPEC_JAM_PATH)"; \
		JAM_PATH="$(GENSPEC_JAM_PATH)" "$(JAMDUNA)" gen-spec "$(CHAINSPEC_CONFIG)" "$(CHAINSPEC)"; \
	fi
	@echo "Generated chainspec: $(CHAINSPEC)"

run-v0 run-v1 run-v2 run-v3 run-v4 run-v5: check-bins prepare
	@idx="$(@:run-v%=%)"; \
	pid_file="$(PIDS_DIR)/v$${idx}.pid"; \
	log_file="$(LOGS_DIR)/jamduna-v$${idx}.log"; \
	if [[ -f "$${pid_file}" ]] && kill -0 "$$(cat "$${pid_file}")" 2>/dev/null; then \
		echo "validator $${idx} already running (pid=$$(cat "$${pid_file}"))"; \
		exit 0; \
	fi; \
	if [[ ! -f "$(CHAINSPEC)" ]]; then \
		echo "Missing chainspec: $(CHAINSPEC)"; \
		echo "Run: make gen-spec"; \
		exit 1; \
	fi; \
	echo "Starting validator $${idx} -> p2p:$$(($(P2P_BASE_PORT)+$${idx})) rpc:$$(($(RPC_BASE_PORT)+$${idx}))"; \
	JAM_PATH="$(JAM_PATH)" "$(JAMDUNA)" run \
		--data-path "$(DATA_PATH)" \
		--chain "$(CHAINSPEC)" \
		--dev-validator "$${idx}" \
		--pvm-backend "$(PVM_BACKEND)" \
		>"$${log_file}" 2>&1 & \
	pid="$$!"; \
	echo "$$pid" > "$${pid_file}"; \
	echo "validator $${idx} started (pid=$$pid, log=$${log_file})"

run-validators: run-v0 run-v1 run-v2 run-v3 run-v4 run-v5
	@echo
	@echo "All validators started."
	@echo "Check status: make status"

run-fib-stream: check-bins prepare
	@if [[ ! -f "$(CHAINSPEC)" ]]; then \
		echo "Missing chainspec: $(CHAINSPEC)"; \
		echo "Run: make gen-spec"; \
		exit 1; \
	fi
	@if [[ -f "$(FIB_STREAM_PID_FILE)" ]] && kill -0 "$$(cat "$(FIB_STREAM_PID_FILE)")" 2>/dev/null; then \
		echo "fib-stream-runner already running (pid=$$(cat "$(FIB_STREAM_PID_FILE)"))"; \
		exit 0; \
	fi
	@echo "Starting fib-stream-runner in background (bundled fib-builder + fib-feeder)..."
	@cd "$(RELEASE_ROOT)" && \
		JAM_PATH="$(JAM_PATH)" \
		FIB_RUNNER_BUILDER_BIN="$(FIB_BUILDER)" \
		FIB_RUNNER_FEEDER_BIN="$(FIB_FEEDER)" \
		"./fib-stream-runner" >"$(FIB_STREAM_LOG)" 2>&1 & \
		pid="$$!"; \
		echo "$$pid" > "$(FIB_STREAM_PID_FILE)"; \
		echo "fib-stream-runner started (pid=$$pid, log=$(FIB_STREAM_LOG))"

run-fib-stream-bg: run-fib-stream
	@echo "run-fib-stream-bg is an alias of run-fib-stream"

stop-fib:
	@if [[ -f "$(FIB_STREAM_PID_FILE)" ]]; then \
		pid="$$(cat "$(FIB_STREAM_PID_FILE)")"; \
		if kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid" 2>/dev/null || true; \
			echo "fib-stream-runner: sent SIGTERM to $$pid"; \
		else \
			echo "fib-stream-runner: stale pid $$pid"; \
		fi; \
		rm -f "$(FIB_STREAM_PID_FILE)"; \
	else \
		echo "fib-stream-runner: already stopped"; \
	fi

health:
	@echo "Checking validator block activity (last $(ACTIVITY_TAIL_LINES) log lines each)..."
	@for idx in 0 1 2 3 4 5; do \
		pid_file="$(PIDS_DIR)/v$${idx}.pid"; \
		is_running=0; \
		if [[ -f "$$pid_file" ]] && kill -0 "$$(cat "$$pid_file")" 2>/dev/null; then \
			is_running=1; \
		fi; \
		if [[ "$$is_running" -ne 1 ]]; then \
			echo "validator $${idx}: STOPPED (no live process)"; \
			continue; \
		fi; \
		log_file="$(LOGS_DIR)/jamduna-v$${idx}.log"; \
		if [[ ! -f "$$log_file" ]]; then \
			echo "validator $${idx}: MISSING log ($$log_file)"; \
		elif tail -n "$(ACTIVITY_TAIL_LINES)" "$$log_file" | grep -q "Imported Block"; then \
			echo "validator $${idx}: OK (Imported Block found)"; \
		else \
			echo "validator $${idx}: WARN (no Imported Block in last $(ACTIVITY_TAIL_LINES) lines)"; \
		fi; \
	done

status:
	@echo "Release root: $(RELEASE_ROOT)"
	@for idx in 0 1 2 3 4 5; do \
		pid_file="$(PIDS_DIR)/v$${idx}.pid"; \
		if [[ -f "$$pid_file" ]]; then \
			pid="$$(cat "$$pid_file")"; \
			if kill -0 "$$pid" 2>/dev/null; then \
				echo "validator $${idx}: RUNNING pid=$$pid p2p=$$(($(P2P_BASE_PORT)+$${idx})) rpc=$$(($(RPC_BASE_PORT)+$${idx}))"; \
			else \
				echo "validator $${idx}: DEAD pid=$$pid (stale pid file)"; \
			fi; \
		else \
			echo "validator $${idx}: STOPPED"; \
		fi; \
	done
	@echo "Logs: $(LOGS_DIR)/jamduna-v*.log"
	@echo "FIB logs: $(LOGS_DIR)/fib-builder-stream-runner.log, $(LOGS_DIR)/fib-feeder-stream-runner.log"
	@if [[ -f "$(FIB_STREAM_PID_FILE)" ]]; then \
		pid="$$(cat "$(FIB_STREAM_PID_FILE)")"; \
		if kill -0 "$$pid" 2>/dev/null; then \
			echo "fib-stream-runner: RUNNING pid=$$pid log=$(FIB_STREAM_LOG)"; \
		else \
			echo "fib-stream-runner: DEAD pid=$$pid (stale pid file)"; \
		fi; \
	else \
		echo "fib-stream-runner: STOPPED"; \
	fi

stop: stop-fib
	@echo "Stopping validators 0..5..."
	@for idx in 0 1 2 3 4 5; do \
		pid_file="$(PIDS_DIR)/v$${idx}.pid"; \
		if [[ -f "$$pid_file" ]]; then \
			pid="$$(cat "$$pid_file")"; \
			if kill -0 "$$pid" 2>/dev/null; then \
				kill "$$pid" 2>/dev/null || true; \
				echo "validator $${idx}: sent SIGTERM to $$pid"; \
			else \
				echo "validator $${idx}: stale pid $$pid"; \
			fi; \
			rm -f "$$pid_file"; \
		else \
			echo "validator $${idx}: already stopped"; \
		fi; \
	done

clean-state: stop
	@echo "Removing state data under $(DATA_PATH) ..."
	@rm -rf "$(DATA_PATH)"
	@mkdir -p "$(DATA_PATH)"
	@echo "State cleaned."
