# Accepted Vulnerability Risk Documentation

**Project:** Inner Circle
**Component:** `inner-circle` container image
**Image tag scanned:** `4.0`
**Image digest:** `sha256:5ea99c65a377b2d8a975594909ec0ca64bfecbbf371a30592a881ecafe2ffbef`
**Base image:** `node:24.19.0-slim` (Debian 12 "bookworm")
**Scan tool:** Amazon Inspector (ECR enhanced scanning, continuous scan)
**Date documented:** 2026-08-23

---

## Summary

Amazon Inspector's enhanced scan of `inner-circle:4.0` returned **3 CRITICAL findings**, down from 200+ CRITICAL findings on the original image build (which used the full `node:24.14.0` Debian image rather than a minimal multi-stage `-slim` build). Remediation history for this reduction is in the "Remediation history" section below.

The 3 remaining CRITICAL findings are all Debian OS-level Perl package vulnerabilities with **no vendor-supplied fix currently available**. They are documented here as accepted risk rather than blockers, per the reasoning below.

---

## Accepted CRITICAL findings

### CVE-2026-13221 — perl

- **Package / version:** `perl` 5.36.0-7+deb12u3
- **CVSS 3.1 base score:** 9.1 (NVD) — `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:H`
- **EPSS score:** 0.00432 (0.43% predicted exploitation likelihood)
- **Fix available:** No (`fixedInVersion: NotAvailable`)
- **Exploit available:** No
- **Source:** Debian Security Tracker
- **Description:** Perl versions through 5.43.9 can produce silently incorrect regular expression matches when an alternation of more than 65,535 fixed string branches is compiled into a trie. The branch-count delta is stored in a 16-bit field; counts above 65,535 overflow the field and the trie's match decision table is truncated without warning, producing false positive and false negative matches. If such a pattern gates an access or filtering decision, the result can be incorrect.
- **Reference:** https://security-tracker.debian.org/tracker/CVE-2026-13221

### CVE-2026-57433 — perl

- **Package / version:** `perl` 5.36.0-7+deb12u3
- **CVSS 3.1 base score:** 9.8 (NVD) — `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`
- **EPSS score:** 0.00357 (0.36% predicted exploitation likelihood)
- **Fix available:** No (`fixedInVersion: NotAvailable`)
- **Exploit available:** No
- **Source:** Debian Security Tracker
- **Description:** Perl's Storable module (versions before 3.41) has a signed integer overflow when deserializing a crafted SX_HOOK record. `retrieve_hook_common` reads a signed 32-bit item count and calls `av_extend` with that count plus one; a count of `I32_MAX` wraps the addition to a negative value, causing a panic during deserialization of a crafted blob passed to `thaw` or `retrieve`.
- **Reference:** https://security-tracker.debian.org/tracker/CVE-2026-57433

### CVE-2026-12087 — perl

- **Package / version:** `perl` 5.36.0-7+deb12u3
- **CVSS 3.1 base score:** 9.1 (NVD) — `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:H`
- **EPSS score:** 0.00374 (0.37% predicted exploitation likelihood)
- **Fix available:** No (`fixedInVersion: NotAvailable`)
- **Exploit available:** No
- **Source:** Debian Security Tracker
- **Description:** Perl's Socket module (versions before 2.041) has an out-of-bounds heap read. `pack_ip_mreq_source()` in Socket.xs checks the length of its source argument after using a stale length carried over from the preceding multiaddr argument, allowing a source value shorter than 4 bytes to pass validation. The subsequent fixed-size copy into the 4-byte `imr_sourceaddr` field can read up to 3 bytes past the end of the source buffer, copying adjacent heap memory into the returned packed structure.
- **Reference:** https://security-tracker.debian.org/tracker/CVE-2026-12087

---

## Risk acceptance rationale

These three findings are accepted as residual risk for the following reasons:

1. **No fix is currently available.** All three report `fixedInVersion: NotAvailable` from Debian's own tracker. There is no image change, base-image bump, or package update that resolves them today; they will be re-evaluated on each scheduled scan (see Monitoring below) and remediated as soon as a Debian security patch is published.

2. **Not reachable through the application's attack surface.** Perl is installed in the Debian 12 runtime image as an operating-system package `(perl-base 5.36.0-7+deb12u3)` and is executable at `/usr/bin/perl`. However, it is not an application dependency of Inner Circle. The application is a Node.js/Express service and its `package.json` contains no Perl dependency or Perl-based runtime component. No application source code or documented runtime path invokes `/usr/bin/perl`, the Perl Storable module, the Perl Socket module, or Perl's regular-expression engine. Exploitation would therefore require an execution path or dependency that causes the vulnerable Perl functionality to process attacker-controlled input; no such execution path has been identified in the current application architecture.

3. **Low real-world exploitation likelihood.** The current EPSS scores are below 0.5%, representing a low estimated probability of exploitation according to EPSS. Amazon Inspector also currently reports no known exploit availability for these findings. 

4. **Defense-in-depth controls reduce blast radius.** The container:
   - Runs as a non-root user (`USER node`), limiting the impact of any code execution achieved through these or other vectors.
   - Is built via a multi-stage Docker build with no compiler toolchain or unnecessary packages in the runtime image.
   - Has no shell access exposed externally.
   - Sits behind a VPC architecture where ECR access is via VPC endpoints (not public internet), and — per the broader project architecture — the application layer runs in private subnets with only the ALB internet-facing.

---

## Risk Treatment Decision: Temporarily Accepted

The three findings are accepted as residual risk for image 4.0 because no vendor remediation is currently available and no application execution path exposing the affected Perl functionality has been identified. Acceptance is conditional and does not constitute permanent remediation. The findings remain subject to continuous monitoring and will be remediated when a vendor-fixed package becomes available.

---

## Remediation history (for context)

| Image tag | Base image | Total CRITICAL findings |
|---|---|---|
| `2.0` | `node:24.14.0` (full Debian, non-multi-stage) | 200+ |
| `3.0` | `node:24.14.0-slim` (multi-stage) | 8 |
| `4.0` | `node:24.19.0-slim` (multi-stage, patched Node) | 3 |

The reduction from 200+ to 8 was achieved by switching from the full `node:24.14.0` image to a multi-stage build using `node:24.14.0-slim`, removing unrelated OS packages (ImageMagick, OpenEXR, PostgreSQL client libraries, Python, Perl dev headers, full build toolchain, etc.) that were incidental to the base image and unrelated to the application's actual dependencies (confirmed via `package.json` — no native/compiled dependencies).

The reduction from 8 to 3 was achieved by bumping the pinned Node version from `24.14.0` to `24.19.0`, which resolved:
- **CVE-2026-48930** (nodejs/node, TLS embedded-NUL hostname authority rebinding) — fixed upstream in Node 24.17.0.
- **CVE-2026-31789** and **CVE-2026-34182** (openssl/openssl, heap buffer overflow in OCTET STRING-to-hex conversion) — resolved via the bundled OpenSSL update in the newer Node build.

---

## Monitoring and review

- The ECR repository has **continuous scanning** enabled (`ScanStatus.status: ACTIVE`), so these findings will be automatically re-evaluated as new scan data becomes available and as Debian publishes patches.
- These three CVEs should be re-checked prior to each production deployment and at minimum monthly, in line with Node.js's own security release cadence.
- If a fix becomes available (`fixedInVersion` populated), the base image should be rebuilt and re-scanned promptly, and this document updated or the relevant CVE removed from the accepted list.
- Recommended future automation (see step 6.14 — GitHub Actions): a scheduled CI job that rebuilds the image against the latest patched Node point release and re-runs Inspector scanning, flagging any newly unresolved CRITICAL/HIGH findings for review.

---

**Documented by:** Ugwokaegbe Princess (Project Owner)
**Next review due:** 2026-09-23 (30 days) or upon next image rebuild, whichever is sooner.