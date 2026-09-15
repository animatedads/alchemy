# Virtual Browser v0.9 architecture

Job placement -> Virtual Browser -> VirtualBrowserObservationSession -> Observation v0.5 stream/service -> Queue Fabric -> monitor/AI.

Browser control remains outside the observation plane. Queue/WLU delivery state cannot mutate browser state, and Observation replay/checkpoints are based on stream sequence rather than DOM generation or Queue Fabric package identity.
