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
| Segment comparison through `Slice#[]` and `memcmp` | `PathSegment` scans with a raw pointer and wrapping arithmetic, and compares literals a word at a time. Profiling showed the sub-slice call and libc `memcmp` at 30–45% of traversal time for short segments. |
| One call frame per static level | `Fragment#find_path_match` loops through levels that have no dynamic siblings or glob, since a static mismatch there is a miss. Levels that could backtrack still recurse, so precedence is unchanged. |
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

Two follow-up candidates were measured and rejected. Keying the snapshot's
static index by path instead of `{method, path}` halves its entries, which keeps
small route tables under Crystal's 16-entry linear-scan threshold and made every
probe slower. Splitting the snapshot node walk into the live matcher's
`find_path`/`find_segment` shape was neutral overall, so the snapshot keeps its
single walk.

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
| static one | 61.4 | 34.2 | 96 | 64 |
| static five | 120.9 | 42.9 | 144 | 64 |
| one capture | 155.1 | 97.9 | 240 | 192 |
| two captures | 229.4 | 124.5 | 320 | 208 |
| optional | 173.4 | 100.7 | 272 | 192 |
| glob | 323.0 | 109.1 | 560 | 208 |
| encoded capture | 237.1 | 107.3 | 464 | 208 |
| encoded glob | 470.7 | 122.8 | 976 | 208 |
| early miss | 124.9 | 11.8 | 160 | 0 |
| late miss | 120.3 | 27.6 | 128 | 0 |
| 16 segments | 360.0 | 77.9 | 400 | 64 |
| 17 segments | 506.8 | 80.6 | 736 | 64 |
| 100 segments | 3284.7 | 363.3 | 5344 | 64 |
| 20 captures | 1692.7 | 978.5 | 3264 | 2432 |
| wrong method | 98.7 | 25.7 | 96 | 0 |
| mixed | 601.2 | 167.1 | 936 | 283 |
| registration | 97743.8 | 69290.8 | 223511 | 152926 |
| optional registration | 47358.8 | 33397.1 | 101792 | 78560 |
| enumeration | 145340.5 | 21545.8 | 344832 | 60592 |
| dynamic backtracking | 685.9 | 360.4 | 272 | 208 |
| dynamic miss | 435.6 | 256.7 | 64 | 0 |
| method backtracking | 682.5 | 348.3 | 272 | 208 |
| method miss | 608.2 | 299.3 | 64 | 0 |

Optional snapshot compared with the live matcher in the same binary:

| Case | Live ns/op | Snapshot ns/op | Live bytes | Snapshot bytes |
|---|---:|---:|---:|---:|
| static one | 34.2 | 28.2 | 64 | 64 |
| static five | 42.9 | 27.4 | 64 | 64 |
| one capture | 97.9 | 89.0 | 192 | 192 |
| two captures | 124.5 | 113.2 | 208 | 208 |
| glob | 109.1 | 97.9 | 208 | 208 |
| encoded capture | 107.3 | 100.5 | 208 | 208 |
| early miss | 11.8 | 15.3 | 0 | 0 |
| late miss | 27.6 | 31.0 | 0 | 0 |
| 17 segments | 80.6 | 31.8 | 64 | 64 |
| 100 segments | 363.3 | 74.0 | 64 | 64 |
| 20 captures | 978.5 | 838.9 | 2432 | 1664 |
| mixed | 167.1 | 122.1 | 283 | 229 |
| dynamic backtracking | 360.4 | 305.3 | 208 | 208 |
| dynamic miss | 256.7 | 213.2 | 0 | 0 |
| method backtracking | 348.3 | 86.7 | 208 | 208 |
| method miss | 299.3 | 10.7 | 0 | 0 |

The snapshot improves static/deep and method-filtered workloads substantially,
but its early/late miss timings can be slightly slower because of the extra
index probe. The live matcher avoids that tradeoff. The payload-only API
allocated zero bytes in all request fixtures here, including encoded dynamic
and glob paths without competing static children. Encoded static comparisons
can still require a decoded string.

## ActionController integration

ActionController 9.0.0 passed all 274 specs with this branch substituted through
`CRYSTAL_PATH`. These figures were taken before the segment-comparison and
static-chain follow-up above, so they understate the current dynamic dispatch gain. Its existing `warmed_dispatch.cr` harness was built against the
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
