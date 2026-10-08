# oobound v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oobound

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oobound-linux-x86_64
	@sha256sum dist/oobound-linux-x86_64 > dist/oobound-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oobound-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing sandbox profile ==="
	@./$(BIN) -P sandbox | grep -q "Memory Maximum" && echo "PASS: sandbox profile"
	@echo "=== testing systemd format output ==="
	@./$(BIN) --format systemd -m 256 -c 50 -- echo ok | grep -q "systemd-run" && echo "PASS: systemd format"
	@echo "=== testing prlimit format output ==="
	@./$(BIN) --format prlimit -m 256 -- echo ok | grep -q "prlimit" && echo "PASS: prlimit format"
	@echo "=== testing cgroup format output ==="
	@./$(BIN) --format cgroup -m 128 | grep -q "memory.max = 128M" && echo "PASS: cgroup format"
	@echo "=== testing audit pass ==="
	@./$(BIN) --audit -P strict | grep -q "PASS" && echo "PASS: audit pass"
	@echo "=== testing json telemetry ==="
	@./$(BIN) --json -P agent | grep -q '"mem_mb":2048' && echo "PASS: json telemetry"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "bound_profile" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call bound_profile ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"bound_profile","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'profiles' && echo "PASS: MCP bound_profile"
	@echo "=== testing MCP tools/call bound_clamp ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"bound_clamp","arguments":{"profile":"sandbox","command":"python worker.py"}}}\n' | ./$(BIN) --mcp | grep -q 'systemd_cmd' && echo "PASS: MCP bound_clamp"
	@echo "=== testing MCP tools/call bound_audit ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"bound_audit","arguments":{"mem_mb":512,"cpu_pct":100,"max_fds":256,"max_procs":64,"timeout_sec":60}}}\n' | ./$(BIN) --mcp | grep -q 'PASS' && echo "PASS: MCP bound_audit"
	@echo "=== testing MCP tools/call bound_stats ==="
	@printf '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"bound_stats","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'oobound' && echo "PASS: MCP bound_stats"
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oobound
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oobound-uninstall
	@echo "installed oobound and oobound-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oobound $(DESTDIR)$(BINDIR)/oobound-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oobound $(HOME)/.config/oobound; echo "purged user cache and config"; fi
	@echo "uninstalled oobound and oobound-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oobound
	@chmod 0755 dist/deb-root/usr/bin/oobound
	@cp uninstall.sh dist/deb-root/usr/bin/oobound-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oobound-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oobound_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oobound_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oobound-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oobound.spec > ~/rpmbuild/SPECS/oobound.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oobound.spec
	@cp ~/rpmbuild/RPMS/x86_64/oobound-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oobound
	@chmod 0755 dist/arch-pkg/usr/bin/oobound
	@cp uninstall.sh dist/arch-pkg/usr/bin/oobound-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oobound-uninstall
	@printf "pkgname = oobound\npkgbase = oobound\npkgver = $(VERSION)-1\npkgdesc = Dynamic memory, CPU cycle, and file descriptor clamp for unvetted subprocesses.\nurl = https://github.com/openOODA-tools/oobound\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oobound\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oobound-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oobound-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum oobound* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
