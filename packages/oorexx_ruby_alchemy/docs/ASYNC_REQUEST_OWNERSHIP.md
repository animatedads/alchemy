# Asynchronous request ownership — dev17

The Ruby-worker callback queue now stores `std::shared_ptr<AsyncRexxCall>`.  The waiter and queue/pump therefore own the request independently.  Removing a request from the queue transfers the queue owner into the owner pump; it does not expose a pointer into another thread's stack.

The request also represents the outstanding Rexx invocation pin.  The pump dispatches without the queue or projection registry mutex held, drops the pin exactly once after dispatch, publishes result/error and completion under the request mutex, and wakes the waiter.

This change establishes storage lifetime needed for future cancellation/shutdown work.  It does **not** define cancellation.  A future state machine must distinguish queued, dispatching, completed and cancelled requests and specify which owner releases the invocation pin in every transition.
