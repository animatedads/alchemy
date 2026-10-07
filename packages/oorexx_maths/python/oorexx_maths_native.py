"""Native/vectorized helper kernels for ooRexx Maths.

Public mathematical meaning remains in the ooRexx classes.  This module only
executes provider-specific numerical kernels and returns diagnostics/evidence.
"""
from __future__ import annotations


def integrate_second_order(mass, damping, stiffness, x0, v0, dt, steps,
                           forces=None, method="NEWMARK_AVERAGE_ACCELERATION",
                           beta=0.25, gamma=0.5, return_history=True):
    """Integrate M x'' + C x' + K x = f with constant matrices.

    Uses Newmark average acceleration (beta=1/4, gamma=1/2).  SciPy LU
    factorizations are computed once for M and the constant effective matrix,
    then reused for every step.  The returned residuals are diagnostics over
    the represented binary64 trajectory; ooRexx Maths can independently replay
    the trajectory through its REFERENCE provider.
    """
    import numpy as np
    import scipy
    from scipy.linalg import lu_factor, lu_solve

    M = np.asarray(mass, dtype=np.float64)
    C = np.asarray(damping, dtype=np.float64)
    K = np.asarray(stiffness, dtype=np.float64)
    x0 = np.asarray(x0, dtype=np.float64).reshape(-1)
    v0 = np.asarray(v0, dtype=np.float64).reshape(-1)
    dt = float(dt)
    steps = int(steps)
    beta = float(beta)
    gamma = float(gamma)

    if M.ndim != 2 or M.shape[0] != M.shape[1]:
        raise ValueError("mass matrix must be square")
    n = M.shape[0]
    if C.shape != (n, n) or K.shape != (n, n):
        raise ValueError("damping/stiffness matrices must match mass matrix")
    if x0.shape != (n,) or v0.shape != (n,):
        raise ValueError("initial displacement/velocity must match system dimension")
    if dt <= 0 or steps < 1:
        raise ValueError("dt must be positive and steps must be >= 1")
    if beta <= 0 or gamma <= 0:
        raise ValueError("Newmark beta/gamma must be positive")
    if not (np.all(np.isfinite(M)) and np.all(np.isfinite(C)) and
            np.all(np.isfinite(K)) and np.all(np.isfinite(x0)) and
            np.all(np.isfinite(v0))):
        raise ValueError("non-finite dynamics input")

    if forces is None:
        F = np.zeros((steps + 1, n), dtype=np.float64)
    else:
        F = np.asarray(forces, dtype=np.float64)
        if F.ndim == 1:
            if F.shape != (n,):
                raise ValueError("constant force vector must match system dimension")
            F = np.repeat(F.reshape(1, n), steps + 1, axis=0)
        elif F.shape != (steps + 1, n):
            raise ValueError("force history must have shape (steps+1, dimension)")
    if not np.all(np.isfinite(F)):
        raise ValueError("non-finite force history")

    method = str(method).upper()
    if method == "NEWMARK":
        method = "NEWMARK_AVERAGE_ACCELERATION"
    if method not in {"NEWMARK_AVERAGE_ACCELERATION", "SYMPLECTIC_EULER"}:
        raise ValueError("unsupported second-order integration method")

    M_lu = lu_factor(M, check_finite=False)

    if method == "SYMPLECTIC_EULER":
        x = np.empty((steps + 1, n), dtype=np.float64)
        v = np.empty((steps + 1, n), dtype=np.float64)
        a = np.empty((steps + 1, n), dtype=np.float64)
        x[0] = x0
        v[0] = v0
        a[0] = lu_solve(M_lu, F[0] - C @ v0 - K @ x0, check_finite=False)
        max_equilibrium = float(np.max(np.abs(M @ a[0] + C @ v[0] + K @ x[0] - F[0])))
        max_x_consistency = 0.0
        max_v_consistency = 0.0
        for i in range(steps):
            ai = lu_solve(M_lu, F[i] - C @ v[i] - K @ x[i], check_finite=False)
            v[i + 1] = v[i] + dt * ai
            x[i + 1] = x[i] + dt * v[i + 1]
            a[i + 1] = lu_solve(M_lu, F[i + 1] - C @ v[i + 1] - K @ x[i + 1], check_finite=False)
            eq = M @ a[i + 1] + C @ v[i + 1] + K @ x[i + 1] - F[i + 1]
            max_equilibrium = max(max_equilibrium, float(np.max(np.abs(eq))))
            xr = x[i + 1] - x[i] - dt * v[i + 1]
            vr = v[i + 1] - v[i] - dt * ai
            max_x_consistency = max(max_x_consistency, float(np.max(np.abs(xr))))
            max_v_consistency = max(max_v_consistency, float(np.max(np.abs(vr))))
        times = np.arange(steps + 1, dtype=np.float64) * dt
        payload = {
            "equilibrium_residual_inf": format(max_equilibrium, ".17g"),
            "kinematic_displacement_residual_inf": format(max_x_consistency, ".17g"),
            "kinematic_velocity_residual_inf": format(max_v_consistency, ".17g"),
            "condition_mass": format(float(np.linalg.cond(M)), ".17g"),
            "condition_effective": "not-applicable",
            "numpy_version": np.__version__, "scipy_version": scipy.__version__,
            "algorithm": "symplectic-euler + scipy-lu-factor-reuse-mass",
            "solver": "scipy.linalg.lu_factor/lu_solve",
        }
        if return_history:
            payload.update(times=times.tolist(), displacement=x.tolist(), velocity=v.tolist(), acceleration=a.tolist())
        else:
            payload.update(time=format(float(times[-1]), ".17g"), displacement=x[-1].tolist(), velocity=v[-1].tolist(), acceleration=a[-1].tolist())
        return payload

    a0c = 1.0 / (beta * dt * dt)
    a1c = gamma / (beta * dt)
    a2c = 1.0 / (beta * dt)
    a3c = 1.0 / (2.0 * beta) - 1.0
    a4c = gamma / beta - 1.0
    a5c = dt * (gamma / (2.0 * beta) - 1.0)

    Keff = K + a0c * M + a1c * C
    K_lu = lu_factor(Keff, check_finite=False)

    x = np.empty((steps + 1, n), dtype=np.float64)
    v = np.empty((steps + 1, n), dtype=np.float64)
    a = np.empty((steps + 1, n), dtype=np.float64)
    x[0] = x0
    v[0] = v0
    a[0] = lu_solve(M_lu, F[0] - C @ v0 - K @ x0, check_finite=False)

    max_equilibrium = float(np.max(np.abs(M @ a[0] + C @ v[0] + K @ x[0] - F[0])))
    max_x_consistency = 0.0
    max_v_consistency = 0.0

    for i in range(steps):
        rhs = (F[i + 1]
               + M @ (a0c * x[i] + a2c * v[i] + a3c * a[i])
               + C @ (a1c * x[i] + a4c * v[i] + a5c * a[i]))
        x[i + 1] = lu_solve(K_lu, rhs, check_finite=False)
        a[i + 1] = a0c * (x[i + 1] - x[i]) - a2c * v[i] - a3c * a[i]
        v[i + 1] = v[i] + dt * ((1.0 - gamma) * a[i] + gamma * a[i + 1])

        eq = M @ a[i + 1] + C @ v[i + 1] + K @ x[i + 1] - F[i + 1]
        max_equilibrium = max(max_equilibrium, float(np.max(np.abs(eq))))
        xr = (x[i + 1] - x[i]
              - dt * v[i]
              - dt * dt * ((0.5 - beta) * a[i] + beta * a[i + 1]))
        vr = (v[i + 1] - v[i]
              - dt * ((1.0 - gamma) * a[i] + gamma * a[i + 1]))
        max_x_consistency = max(max_x_consistency, float(np.max(np.abs(xr))))
        max_v_consistency = max(max_v_consistency, float(np.max(np.abs(vr))))

    times = np.arange(steps + 1, dtype=np.float64) * dt
    payload = {
        "equilibrium_residual_inf": format(max_equilibrium, ".17g"),
        "kinematic_displacement_residual_inf": format(max_x_consistency, ".17g"),
        "kinematic_velocity_residual_inf": format(max_v_consistency, ".17g"),
        "condition_mass": format(float(np.linalg.cond(M)), ".17g"),
        "condition_effective": format(float(np.linalg.cond(Keff)), ".17g"),
        "numpy_version": np.__version__,
        "scipy_version": scipy.__version__,
        "algorithm": "newmark-average-acceleration-beta1/4-gamma1/2 + scipy-lu-factor-reuse",
        "solver": "scipy.linalg.lu_factor/lu_solve",
    }
    if return_history:
        payload.update(times=times.tolist(), displacement=x.tolist(), velocity=v.tolist(), acceleration=a.tolist())
    else:
        payload.update(time=format(float(times[-1]), ".17g"), displacement=x[-1].tolist(), velocity=v[-1].tolist(), acceleration=a[-1].tolist())
    return payload


def integrate_second_order_projected(mass, damping, stiffness, input_matrix,
                                     displacement_output, velocity_output,
                                     x0, v0, dt, steps, inputs=None,
                                     method="SYMPLECTIC_EULER",
                                     beta=0.25, gamma=0.5):
    """Integrate second-order dynamics and return selected linear outputs.

    Solves M x'' + C x' + K x = B u and returns
    y = Hx x + Hv v, plus the final full state.  The channel matrices carry no
    domain meaning here; callers define what each input/output represents.
    """
    import numpy as np

    M = np.asarray(mass, dtype=np.float64)
    B = np.asarray(input_matrix, dtype=np.float64)
    Hx = np.asarray(displacement_output, dtype=np.float64)
    Hv = np.asarray(velocity_output, dtype=np.float64)
    n = M.shape[0]
    if B.ndim != 2 or B.shape[0] != n:
        raise ValueError("input matrix must have shape (dimension, input_count)")
    if Hx.ndim != 2 or Hv.ndim != 2 or Hx.shape != Hv.shape or Hx.shape[1] != n:
        raise ValueError("output matrices must have matching shape (output_count, dimension)")
    m = B.shape[1]
    if inputs is None:
        U = np.zeros((int(steps) + 1, m), dtype=np.float64)
    else:
        U = np.asarray(inputs, dtype=np.float64)
        if U.ndim == 1 and m == 1:
            U = U.reshape(-1, 1)
        if U.shape != (int(steps) + 1, m):
            raise ValueError("input history must have shape (steps+1, input_count)")
    F = U @ B.T
    raw = integrate_second_order(mass, damping, stiffness, x0, v0, dt, steps,
                                 F, method, beta, gamma, True)
    X = np.asarray(raw["displacement"], dtype=np.float64)
    V = np.asarray(raw["velocity"], dtype=np.float64)
    Y = X @ Hx.T + V @ Hv.T
    raw["outputs"] = Y.tolist()
    raw["final_displacement"] = X[-1].tolist()
    raw["final_velocity"] = V[-1].tolist()
    raw["final_acceleration"] = np.asarray(raw["acceleration"], dtype=np.float64)[-1].tolist()
    raw["input_count"] = str(m)
    raw["output_count"] = str(Hx.shape[0])
    raw["algorithm"] = raw["algorithm"] + " + native-B/H-projection"
    return raw


def run_discrete_state_space(state_matrix, input_matrix, output_matrix,
                             feedthrough_matrix, initial_state, inputs):
    """Run a discrete LTI state-space block.

    Convention is y[k] = C x[k] + D u[k], followed by
    x[k+1] = A x[k] + B u[k].  All values are binary64; domain meaning of
    state/input/output channels remains with the ooRexx caller.
    """
    import numpy as np

    A = np.asarray(state_matrix, dtype=np.float64)
    B = np.asarray(input_matrix, dtype=np.float64)
    C = np.asarray(output_matrix, dtype=np.float64)
    D = np.asarray(feedthrough_matrix, dtype=np.float64)
    x = np.asarray(initial_state, dtype=np.float64).reshape(-1)
    U = np.asarray(inputs, dtype=np.float64)

    if A.ndim != 2 or A.shape[0] != A.shape[1] or A.shape[0] < 1:
        raise ValueError("A must be a non-empty square matrix")
    n = A.shape[0]
    if B.ndim != 2 or B.shape[0] != n or B.shape[1] < 1:
        raise ValueError("B must have shape (state_count, input_count)")
    m = B.shape[1]
    if C.ndim != 2 or C.shape[1] != n or C.shape[0] < 1:
        raise ValueError("C must have shape (output_count, state_count)")
    q = C.shape[0]
    if D.shape != (q, m):
        raise ValueError("D must have shape (output_count, input_count)")
    if x.shape != (n,):
        raise ValueError("initial state must match state count")
    if U.ndim == 1 and m == 1:
        U = U.reshape(-1, 1)
    if U.ndim != 2 or U.shape[1] != m:
        raise ValueError("inputs must have shape (sample_count, input_count)")
    if not all(np.all(np.isfinite(z)) for z in (A, B, C, D, x, U)):
        raise ValueError("non-finite discrete state-space input")

    Y = np.empty((U.shape[0], q), dtype=np.float64)
    for k in range(U.shape[0]):
        u = U[k]
        Y[k] = C @ x + D @ u
        x = A @ x + B @ u

    return {
        "outputs": Y.tolist(),
        "final_state": x.tolist(),
        "samples": str(U.shape[0]),
        "algorithm": "numpy-discrete-state-space-block",
    }
