# Melodic regression corpus

Drop ~15-second WAV clips here, plus a `<basename>.expected.json` alongside
each clip with:

```json
{ "bpm": 72.0, "tolerance": 1.0, "notes": "Piano + vocal ballad, Adele 'Hello'" }
```

Run with: `BLAQ_RUN_CORPUS=1 dart test test/regression/melodic_corpus_test.dart`

This corpus is NOT committed binary audio — fixtures are added locally and
gitignored. Results are summarized in `docs/corpus_results_<version>.md`.
