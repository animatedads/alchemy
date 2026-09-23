/* Deprecated compatibility entry.
 * v0.2-dev8 requires the standard migratable NEW contract, explicit camera
 * wall-clock window, and Job-to-Node placement/ownership binding. Use the
 * generic launch-spec builder instead of generating a partial direct-worker
 * spec here.
 */
say 'FD_LAUNCH_SPEC_ERROR make_tp00000_launch_spec.rex is deprecated in v0.2-dev8'
say 'Use tools/make_fd_window_launch_spec.rex with explicit wall-clock and Job-to-Node authority fields.'
exit 66
