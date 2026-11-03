# Backend upgrade and measured evaluation

The default backend now combines HHEM-2.1-Open document consistency with DeBERTa-v3-base claim verification, evidence retrieval, explicit disagreement reporting and bounded local inference.

On fresh, source-disjoint samples the updated detector scored **70.0% on HaluBench** and **66.7% on RAGTruth**, with **100% document scoring coverage** on both 60-example samples. These are small local evaluations, not official leaderboard scores.

## Final source-disjoint evaluation

Implementation and the default 0.5 binary decision threshold were frozen before these results were inspected. Seed 20261028; 60 test examples per dataset, balanced across label and source/task. All source groups in both earlier seed-42 diagnostic files, including their development partitions, were excluded. The unused local development partitions of the final files were not used for tuning.

### HaluBench — 60 examples

| Verifier | Accuracy on scored rows | AUROC | Hallucination F1 | Scoring coverage | Errors |
|---|---:|---:|---:|---:|---:|
| Word overlap | 53.3% | 0.588 | 0.391 | 100.0% | 0 |
| Original context comparator | 53.3% | 0.585 | 0.641 | 100.0% | 0 |
| HHEM-2.1-Open comparator | 69.2% | 0.710 | 0.692 | 86.7% | 8 |
| Updated hybrid | 70.0% | 0.726 | 0.679 | 100.0% | 0 |

### RAGTruth — 60 examples

| Verifier | Accuracy on scored rows | AUROC | Hallucination F1 | Scoring coverage | Errors |
|---|---:|---:|---:|---:|---:|
| Word overlap | 55.0% | 0.663 | 0.341 | 100.0% | 0 |
| Original context comparator | 50.0% | 0.626 | 0.667 | 100.0% | 0 |
| HHEM-2.1-Open comparator | 66.7% | 0.702 | 0.600 | 100.0% | 0 |
| Updated hybrid | 66.7% | 0.700 | 0.600 | 100.0% | 0 |

Accuracy is computed on scored rows. Always read it with coverage; the full JSON reports also count abstentions/errors as incorrect in a separate metric. The HHEM comparator uses a local 2,048-token budget and explicitly fails larger inputs. That is this adapter's configured resource limit, not a claim about HHEM's inherent context capacity. The hybrid uses a reported retrieved-claim fallback on long inputs.

### Matched comparison with HHEM

These comparisons use exactly the same IDs that all four adapters successfully scored:

| Dataset | Common examples | Updated hybrid accuracy | Original context accuracy | HHEM accuracy |
|---|---:|---:|---:|---:|
| halubench | 52 | 67.3% | 48.1% | 69.2% |
| ragtruth | 60 | 66.7% | 50.0% | 66.7% |

The samples are small and confidence intervals are wide. This demonstrates measurable backend improvement and comparison on common data; it does not establish superiority over HHEM or parity with a published leaderboard.

### Uncertainty and compute

| Dataset | Updated balanced accuracy, source-cluster 95% interval | Median request latency | P95 request latency |
|---|---:|---:|---:|
| halubench | 70.0% [58.8%, 81.3%] | 0.45 s | 3.90 s |
| ragtruth | 66.7% [56.2%, 76.2%] | 1.85 s | 5.43 s |

Measured locally on an NVIDIA RTX 3050 Laptop GPU for the hybrid and HHEM. The original comparator preserves its CPU inference path, so these runs are not a fair GPU-versus-CPU speed benchmark. Cold model loading is included in the first request. The hybrid spends substantially more compute on claim explanations than the standalone HHEM comparator.

## Development diagnostics — preserved

These 120-example subsets were used to identify weaknesses during development. They motivated the dedicated document verifier and are not untouched final holdouts.

### HaluBench diagnostic subset

| Verifier | Accuracy on scored rows | AUROC | Hallucination F1 | Scoring coverage | Errors |
|---|---:|---:|---:|---:|---:|
| Word overlap | 57.5% | 0.633 | 0.532 | 100.0% | 0 |
| Original context comparator | 60.8% | 0.638 | 0.701 | 100.0% | 0 |
| HHEM-2.1-Open comparator | 68.9% | 0.745 | 0.729 | 85.8% | 17 |
| Updated hybrid | 72.5% | 0.751 | 0.732 | 100.0% | 0 |

### RAGTruth diagnostic subset

| Verifier | Accuracy on scored rows | AUROC | Hallucination F1 | Scoring coverage | Errors |
|---|---:|---:|---:|---:|---:|
| Word overlap | 56.7% | 0.628 | 0.366 | 100.0% | 0 |
| Original context comparator | 50.0% | 0.665 | 0.667 | 100.0% | 0 |
| HHEM-2.1-Open comparator | 66.4% | 0.735 | 0.592 | 99.2% | 1 |
| Updated hybrid | 65.0% | 0.735 | 0.571 | 100.0% | 0 |

The early NLI-only implementation is also preserved in reports/*-nli-initial.json. Its conservative minimum-claim score overflagged correct answers and produced many claim conflicts in long documents. The default hybrid retains claim evidence and disagreements while using the dedicated consistency model for the document score.

A 30-example development-only threshold selection example is saved in reports/halubench-threshold-pipeline.json. It changes the precision/recall tradeoff and was not adopted as the service default or applied to the final source-disjoint evaluation. Decision cutoff fitting does not calibrate model probabilities.

## What the metrics mean

- Positive label 1 means hallucinated/ungrounded; 0 means supported.
- Scores are source-grounded document-risk estimates, not world-truth probabilities.
- Accuracy measures the document risk score at the listed threshold. It does not measure the displayed three-way claim labels or the broader requires_review flag, which also covers disagreements.
- The original context comparator applies the preserved v1 context detector sentence by sentence and uses minimum support for a common document score. The original context endpoint did not expose this same document metric. The separate lexical comparator reproduces the old reference-overlap signal.
- HaluBench includes questions. The hybrid conditions its document verifier on the question; the original and standalone HHEM pair comparators use source/answer pairs. This difference is recorded and should be considered when interpreting results.
- HaluBench and RAGTruth contain overlapping task families, so their results are reported separately rather than pooled into one score.
- Each report includes per-task breakdowns, labels, IDs, scores, errors, threshold, source-cluster intervals, input hashes and model revisions. Raw benchmark source text is not bundled.

## Verification

- 76 deterministic regression tests passed, including claim extraction, offsets, conflict handling, probability integrity, arithmetic scope/units, API failures, concurrency limits, benchmark label polarity/leakage, PDF/DOCX extraction and hybrid fallback.
- React production build and ESLint passed.
- A real-model FastAPI smoke test passed, including warmup, readiness, a supported claim and a contradicted claim.
- Native HHEM reproduced the published model-card example score: 0.0543237 versus the published rounded 0.0543. See [the HHEM model card](https://huggingface.co/vectara/hallucination_evaluation_model) and [the smoke result](reports/api-smoke.json).

## Reproduce

Install requirements-dev.txt and download models as described in README.md. Prepare the seed-42 diagnostic files first, then prepare the final files with source exclusions:

~~~powershell
python -m benchmarks.prepare --dataset halubench --output data/halubench.jsonl --limit 120 --seed 42
python -m benchmarks.prepare --dataset ragtruth --output data/ragtruth.jsonl --limit 120 --seed 42
python -m benchmarks.prepare --dataset halubench --output data/final-halubench.jsonl --limit 60 --seed 20261028 --exclude data/halubench.jsonl data/ragtruth.jsonl
python -m benchmarks.prepare --dataset ragtruth --output data/final-ragtruth.jsonl --limit 60 --seed 20261028 --exclude data/halubench.jsonl data/ragtruth.jsonl
python -m benchmarks.run --data data/final-halubench.jsonl --adapter pipeline --output reports/final-halubench-pipeline.json
python -m benchmarks.run --data data/final-ragtruth.jsonl --adapter pipeline --output reports/final-ragtruth-pipeline.json
~~~

Repeat with original, lexical and hhem adapters. Use benchmarks.compare to compare saved predictions on common IDs. Model weights, normalized inputs and prepared manifests are pinned/fingerprinted. The source-group exclusion manifests and backend implementation freeze are in reports/.

## Practical limits

Structured data-to-text, answer fragments, cross-sentence references, and multi-step reasoning remain difficult. NLI claim decisions are estimates and can disagree with HHEM. Long-source retrieval can miss evidence. PDF extraction does not provide OCR. Sources can themselves be false. More extensive external evaluation and probability calibration are needed before claiming benchmark parity or using the scores as automatic ground truth.

HaluBench is CC-BY-NC-2.0. RAGTruth and TRUE constituent sources carry their own licenses. The archive includes code and derived evaluation reports, not benchmark text or model weights.
