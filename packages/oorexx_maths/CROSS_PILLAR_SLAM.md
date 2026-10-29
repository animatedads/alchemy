# SLAM cross-pillar boundary — Maths v0.20 candidate2

Architecture: Tom Dyer. Maths implementation: ChatGPT GPT-6. SLAM implementation inspected: Claude Opus 5.5, `oorexx_slam_v0.1-1.zip`.

SLAM is the Small Language Autonomous Model. Its authority is code segmentation, graph/node identity, edge evidence, task/path selection, word grounding, tested anchors and language composition. Maths must not decide those semantics.

Maths owns reusable numerical operations. Candidate2 adds `MathStatistics` so SLAM does not need to own private implementations of sum/mean/median/mode/range/deviation/square/variance/stddev or square root. The proposed SLAM adapter keeps its current list-in/list-out word interface and delegates:

- add/sum -> `MathStatistics~sum`
- count -> `~count`
- mean -> `~mean`
- median -> `~median`
- mode -> `~uniqueMode`
- range -> `~range`
- deviation -> `~deviations`
- square/squares -> `~squaredValues`
- variance -> `~populationVariance`
- standard deviation -> `~populationStdDev`
- root -> existing `.Maths~sqrt`
- multiply -> `~product`

Subtract/divide remain ordered language folds in the SLAM adapter using Maths-coerced values; they are not statistical reductions. SLAM continues to qualify every word->code anchor and may refuse an operation until its TESTED edge reaches the required rate. Maths success is not SLAM grounding success.
