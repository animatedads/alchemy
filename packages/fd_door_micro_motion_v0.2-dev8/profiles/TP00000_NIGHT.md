# TP00000_NIGHT compatibility profile

This profile remains for original v0.2-dev1 qualification and uses the known TP00000 reference frame around media `01:32:55` to seed the F11 fingerprint.

It **does not** contain the 03:12–03:28 exclusion. That period belongs to wall-clock `2023-10-10 03:12–03:28`, which occurs in `20231010_030155_tp00002.mp4`, not TP00000.

New multi-file night jobs should use `FD_NIGHT_F11` with explicit wall-clock origin/start/end and per-job exclusions.
