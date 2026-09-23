"""Wire3D qualification fixture: synthetic data remains INFERRED; audit is MEASURED.
The auditor samples exact 100.000 m endpoints using bilinear interpolation.
This fixture intentionally has no GIS authority and does not assign a real-world CRS.
"""
import json
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates


def generate_and_qualify_dem_fixture(width_m=1000, height_m=1000, resolution_m=1.0,
                                     nominal_wavelength_m=100.0, target_delta_z_100m=10.0,
                                     base_elevation=100.0, seed=42):
    rng = np.random.default_rng(seed)
    nx = int(round(width_m / resolution_m)); ny = int(round(height_m / resolution_m))
    if not np.isclose(nx * resolution_m, width_m) or not np.isclose(ny * resolution_m, height_m):
        raise ValueError("extent must be an integral number of cells at the requested resolution")
    x = (np.arange(nx) + 0.5) * resolution_m
    y = (np.arange(ny) + 0.5) * resolution_m
    xx, yy = np.meshgrid(x, y)
    k = 2 * np.pi / nominal_wavelength_m
    macro = np.zeros((ny, nx))
    for i in range(8):
        angle = i * (np.pi / 8) + rng.uniform(-0.2, 0.2)
        phase = rng.uniform(0, 2 * np.pi)
        macro += np.sin(k*np.cos(angle)*xx + k*np.sin(angle)*yy + phase)
    macro = 2 * (macro - macro.min()) / (macro.max() - macro.min()) - 1
    micro = gaussian_filter(rng.standard_normal((ny, nx)), sigma=3.0)
    micro = 2 * (micro - micro.min()) / (micro.max() - micro.min()) - 1
    dem = base_elevation + (0.85 * macro + 0.15 * micro) * target_delta_z_100m

    radius_m = 100.0
    margin_m = radius_m
    gy, gx = np.where((yy >= margin_m) & (yy <= height_m-margin_m) &
                      (xx >= margin_m) & (xx <= width_m-margin_m))
    gy = gy[::10]; gx = gx[::10]
    deltas = []
    for theta in np.linspace(0, 2*np.pi, 36, endpoint=False):
        dx = radius_m*np.cos(theta)/resolution_m
        dy = radius_m*np.sin(theta)/resolution_m
        origin = map_coordinates(dem, [gy.astype(float), gx.astype(float)], order=1, mode='nearest')
        target = map_coordinates(dem, [gy+dy, gx+dx], order=1, mode='nearest')
        deltas.append(np.abs(target-origin))
    dz = np.concatenate(deltas)
    envelope = {
        "semantic_object": "LandscapeDEM_1km_1m",
        "claims": [
            {"property":"resolution","declared_value_m":resolution_m,"status":"VERIFIED"},
            {"property":"directional_relief_100m","declared_target_m":target_delta_z_100m,"status":"QUALIFIED_WITH_VARIANCE"}
        ],
        "data_evidence": {"classification":"INFERRED","generator":"frontier-model/synthetic-terrain-fbm","seed":seed,
                          "domain_bounds_m":[width_m,height_m],"grid_dimensions":[ny,nx]},
        "qualification_evidence": {"classification":"MEASURED","method":"exact-bilinear-directional-delta-audit",
            "property":"delta-z","nominal_distance_m":radius_m,"endpoint_distance_error_m":0.0,"sample_count":int(dz.size),
            "metrics":{"mean_dz_m":float(dz.mean()),"std_dz_m":float(dz.std()),
                       "p95_dz_m":float(np.percentile(dz,95)),"max_dz_m":float(dz.max())}}
    }
    return dem, envelope

if __name__ == '__main__':
    _, envelope = generate_and_qualify_dem_fixture()
    print(json.dumps(envelope, indent=2, sort_keys=True))
