# Router performance

Run the release harness with a quiet CPU:

```sh
crystal build benchmarks/performance.cr --release -o /tmp/router-performance
/tmp/router-performance > /tmp/router-performance.jsonl
```

The harness warms each case, measures seven samples, and reports median
nanoseconds and GC-allocated bytes per operation. Request cases perform one
lookup per operation; registration cases build an entire 100-route or 20-route
router; enumeration returns all routes in a 100-route router. Checksums consume
results and guard against differences between revisions. `BENCH_ITERATIONS` and
`BENCH_SAMPLES` can override the request count and sample count. Compile and run
the *same harness* against both revisions, then compare:

```sh
python3 benchmarks/compare.py /tmp/base.jsonl /tmp/pr.jsonl
```

CI uses the PR harness for both the base and head. The job summary and downloadable
artifact include all timings and allocation counts, flag time regressions above
15% and allocation increases, and fail comparison when existing result checksums
or benchmark cases differ. Timings from shared CI runners are review signals.

## Implemented changes

| Audit candidate | Implementation |
|---|---|
| Repeated capture-name allocation | `PathPart#name` is computed once at registration; equality and hashing still depend on the original part. |
| Eager path splitting and 16-segment heap cliff | `Fragment#find_path_match` walks borrowed byte views and copies only successful captures. |
| Single static-child lookup | Compare the sole literal directly, reading the live Hash each time. |
| Repeated scanning during dynamic backtracking | Sibling traversal reuses a parsed lookahead segment without allocating a cache. |
| Glob concatenation | `PathSegment.glob_value` copies or decodes the suffix once. |
| Encoded intermediate strings | `PathReader.decode_range` writes decoded bytes into one bounded string allocation. Decoding is deferred where no static lookup requires it. |
| Capture-hash resizing | Snapshots preallocate hashes for more than eight known distinct captures; the live matcher keeps mutable-tree compatibility. |
| Empty parameter hashes | Existing `Match` ownership is preserved. The additive `match_payload` API skips parameter hashes and capture strings. |
| Static-route indexing | Opt-in `Matcher#compile` returns a snapshot with an exact static index. |
| Excessive trie objects | Live fragments lazily allocate their mutable containers; snapshots compress literal runs. |
| Unnecessary dynamic branches | Snapshots group siblings by reachable method while keeping insertion order and capture names. |
| Optional-route registration | One ordered scan per variant replaces intermediate index slices and repeated membership tests; routes without optionals have a direct path. |
| Duplicate-key normalization | Canonical parts stream into one string builder, and methods are lowercased once per registration. |
| Route enumeration | `Fragment#each_route` reuses one DFS path stack. `collect_routes` copies only emitted paths and `list_routes` formats directly from the stack. |
| Hidden benchmark regressions | Per-case timings, misses, deep paths, encoded paths, mixed traffic, registration, enumeration, allocation counts, and result checksums replace the batch-only CI comparison. |

## Compatibility decisions

An automatic static cache on the live matcher would go stale when callers mutate
`root.static_parts`, `dynamic_parts`, `glob_part`, or `method_to_payload`. Indexing
and compression therefore require an explicitly created snapshot. Snapshots add
an index probe before dynamic traversal and use additional memory; benchmark the
actual workload before choosing them.

Dynamic siblings with different parameter names are not merged. Their order can
change the selected route even when their structural prefixes look identical.
For example, registering `/:a/:tail/x` before `/:b/fixed/:tail` makes the first
route win for `/foo/fixed/x`. Merging those prefixes and applying static precedence
would select the second route. Reusing lookahead and filtering by method preserve
that behavior without rebuilding dispatch priority rules.

Reserving hash capacity for one or two captures increased allocations: Crystal
reserves at least eight entries, whereas incremental growth starts at four.
Snapshots therefore reserve only when more than eight distinct captures are
known. Live matches retain incremental growth because leaves can be shared and
changed through the public route containers.

A shared empty hash or lazy `Match#params` would change mutable ownership or the
aliasing of copied `Match` structs. The existing API retains a fresh hash; callers
that do not need captures can use `match_payload` instead.

Malformed escapes, literal `+`, raw bytes, decoded slashes, internal empty
segments, and the historical percent scanner's delimiter skipping are preserved.
The decoder's output buffer is bounded by the input byte count. A deterministic
spec compares streaming and snapshot traversal with the public segment-array
Fragment API; an additional external run compared 100,000 generated paths with
the unchanged baseline implementation.

## Measurements

The baseline
is upstream `9959945af37f5215b2d3528e9b2525739de93894` (0.6.2), using Crystal 1.21.0
in release mode on an Apple M4 Pro. These numbers describe this workload and
machine, rather than universal performance guarantees.

Existing `Matcher#match` API (nanoseconds and allocated bytes per operation):

| Case | Baseline ns/op | PR ns/op | Baseline bytes | PR bytes |
|---|---:|---:|---:|---:|
| static one | 61.5 | 42.6 | 96 | 64 |
| static five | 123.2 | 63.1 | 144 | 64 |
| one capture | 154.2 | 109.4 | 240 | 192 |
| two captures | 229.7 | 139.6 | 320 | 208 |
| optional | 176.0 | 111.3 | 272 | 192 |
| glob | 326.7 | 121.9 | 560 | 208 |
| encoded capture | 241.6 | 118.7 | 464 | 208 |
| encoded glob | 475.2 | 134.8 | 976 | 208 |
| early miss | 127.0 | 16.5 | 160 | 0 |
| late miss | 125.0 | 36.5 | 128 | 0 |
| 16 segments | 361.2 | 144.8 | 400 | 64 |
| 17 segments | 531.3 | 144.1 | 736 | 64 |
| 100 segments | 3326.2 | 924.9 | 5344 | 64 |
| 20 captures | 1739.0 | 1031.0 | 3264 | 2432 |
| wrong method | 102.2 | 33.7 | 96 | 0 |
| mixed | 606.3 | 229.2 | 936 | 283 |
| registration | 99209.6 | 68536.2 | 223495 | 152916 |
| optional registration | 48157.1 | 33469.2 | 101792 | 78557 |
| enumeration | 146226.5 | 22164.9 | 344831 | 60592 |
| dynamic backtracking | 668.1 | 566.4 | 272 | 208 |
| dynamic miss | 422.3 | 253.5 | 64 | 0 |
| method backtracking | 662.1 | 559.7 | 272 | 208 |
| method miss | 590.5 | 499.1 | 64 | 0 |

Optional snapshot compared with the live matcher in the same binary:

| Case | Live ns/op | Snapshot ns/op | Live bytes | Snapshot bytes |
|---|---:|---:|---:|---:|
| static one | 42.6 | 29.1 | 64 | 64 |
| static five | 63.1 | 28.5 | 64 | 64 |
| one capture | 109.4 | 103.4 | 192 | 192 |
| two captures | 139.6 | 129.0 | 208 | 208 |
| glob | 121.9 | 114.1 | 208 | 208 |
| encoded capture | 118.7 | 112.0 | 208 | 208 |
| early miss | 16.5 | 20.2 | 0 | 0 |
| late miss | 36.5 | 43.3 | 0 | 0 |
| 17 segments | 144.1 | 31.7 | 64 | 64 |
| 100 segments | 924.9 | 75.9 | 64 | 64 |
| 20 captures | 1031.0 | 868.6 | 2432 | 1664 |
| mixed | 229.2 | 133.4 | 283 | 229 |
| dynamic backtracking | 566.4 | 509.9 | 208 | 208 |
| dynamic miss | 253.5 | 214.4 | 0 | 0 |
| method backtracking | 559.7 | 98.5 | 208 | 208 |
| method miss | 499.1 | 12.1 | 0 | 0 |

The snapshot improves static/deep and method-filtered workloads substantially,
but its early/late miss timings can be slightly slower because of the extra
index probe. The live matcher avoids that tradeoff. The payload-only API
allocated zero bytes in all request fixtures here, including encoded dynamic
and glob paths without competing static children. Encoded static comparisons
can still require a decoded string.

## ActionController integration

ActionController 9.0.0 passed all 274 specs with this branch substituted through
`CRYSTAL_PATH`. Its existing `warmed_dispatch.cr` harness was built against the
original LuckyRouter baseline and this branch, then run base/PR/PR/base with no
other builds or tests running. Each case uses 15 samples of 100,000 requests
after warmup. The table averages the two per-process medians:

| Handler operation | Baseline ns/request | PR ns/request | Baseline bytes | PR bytes |
|---|---:|---:|---:|---:|
| single static | 343.8 | 343.4 | 976 | 976 |
| single dynamic | 403.6 | 395.9 | 1200 | 1184 |
| single nested | 503.0 | 468.7 | 1408 | 1360 |
| single base accessor | 333.7 | 332.2 | 976 | 976 |
| mounted static | 339.0 | 340.2 | 976 | 976 |
| mounted dynamic | 409.8 | 400.2 | 1200 | 1184 |
| mounted nested | 512.0 | 486.8 | 1424 | 1376 |
| mounted base accessor | 339.5 | 344.6 | 976 | 976 |

Static/base-accessor differences are within about 1.5% in these runs, with
unchanged allocation counts. Dynamic dispatch improves about 2–7% and removes
16–48 bytes per request. These fixtures show no material warmed single-handler
or declarative-mount regression; they do not cover every application workload.
