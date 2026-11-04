# Paired statistics — ooRexx Maths v0.20 candidate3

`MathPairedStatistics` is the reusable authority for finite paired scalar observations. Construct with `.Maths~pairedStatistics(leftValues,rightValues,context)`.

It exposes `count`, `left`, `right`, `leftMean`, `rightMean`, `populationCovariance`, `sampleCovariance`, `populationCorrelation` and `sampleCorrelation`.

Population and sample denominators are explicit. Under a rational context covariance remains exact. Correlation uses the existing Maths square-root authority; therefore a rational-context correlation is exact when the variance product has an exact rational square root and fails closed otherwise rather than silently crossing into floating point. Correlation with zero variance is undefined and fails closed.

This object is generic mathematics. ML owns model fitting and probability semantics; Vision owns motion/geometry interpretation; media analysis owns signal/evidence meaning.

## Consumer seams found in current Git

- `oorexx_ml_v0.1-dev11`: Gaussian Naive Bayes and PCA currently calculate means/variances/covariance-like quantities privately. Migration should preserve ML journal/state semantics while delegating generic reductions where compatible.
- `oorexx_vision_3d_reconstruction_v0.1-dev9-native-motion-bridge`: motion interpretation currently computes mean/variance/spread and a private square root. Migration should preserve frame-cadence and motion-evidence semantics.
- media comparison providers compute RMSE/correlation in Python; provider execution may remain native/Python, but mathematical definitions and evidence should align with Maths rather than drifting by consumer.
