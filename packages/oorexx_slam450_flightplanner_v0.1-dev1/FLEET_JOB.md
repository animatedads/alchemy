# Fleet job: glide and energy study, coast and alpine routes, 24-31 Oct 2026

For: CODEX-PC, on one ed209 node. Asked by: CLAUDE. Architecture: Tom Dyer.

Run the steps in order. Do not change any file in this package. If a step fails, stop and reply with what it printed.

## What it does

For two routes from Sydney to Melbourne, the coast and the alpine route over Mt Kosciuszko, it fetches ERA5 hourly wind, weather and ground height for every waypoint (Open-Meteo archive, through Alchemy's API Client). It then flies the planned fixed-wing schedule through each day of 24-31 Oct 2026 (AEDT) on both routes. The fetch runs from 23 Oct UTC, because 06:00 AEDT on 24 Oct is 19:00 UTC on 23 Oct. It writes `out/FLEET_RESULT.txt`. About 6 HTTPS requests, under 2 MB, a few minutes.

## Steps

1. Pick an ed209 node where all three are true:

   ```
   uname -m
   ```
   prints `x86_64`;

   ```
   rexx -v
   ```
   prints ooRexx 5.3.0; and

   ```
   curl -sS -o /dev/null -w "%{http_code}\n" "https://archive-api.open-meteo.com/v1/archive?latitude=-33.83&longitude=151.29&start_date=2026-10-31&end_date=2026-10-31&hourly=wind_speed_10m"
   ```
   prints `200`. (curl is used only for this reachability check; the job itself fetches through the API Client.)

2. Get the branch:

   ```
   git fetch origin slam450-flightplanner/dev1-20261107
   git checkout slam450-flightplanner/dev1-20261107
   git pull --ff-only origin slam450-flightplanner/dev1-20261107
   ```

3. From the repository root, set the environment. Put the node's ed209 name (for example ed209h) in the second line:

   ```
   . packages/oorexx_slam450_flightplanner_v0.1-dev1/bin/fp_env.sh
   export FP_NODE=ed209h
   ```

4. Run the job from the package folder:

   ```
   cd packages/oorexx_slam450_flightplanner_v0.1-dev1
   rexx tools/fp_fleet_job.rex
   ```

   A progress log prints as it runs. It ends with `done; send back out/FLEET_RESULT.txt` and exit code 0.

5. If it printed `KIT CHECK FAILED`, or the exit code is not 0: do not fix anything. Reply to CLAUDE with the whole of `out/FLEET_RESULT.txt` and the last 30 lines of the log.

6. If it finished: commit the outputs and push to the same branch.

   ```
   git add out/
   git commit -m "Flight planner fleet job: coast and alpine routes, ERA5 23-31 Oct 2026 (node NAME)"
   git push origin slam450-flightplanner/dev1-20261107
   ```

   Put the node's ed209 name where it says NAME.

7. Reply to CLAUDE on the slam-450 lane with the commit id and the whole of `out/FLEET_RESULT.txt`.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Done. |
| 3 | Kit check failed. Nothing was fetched. |
| 4 | Wind fetch failed. The `evidence\|` lines in the wind file show the status of each request. |

## Licence of the data

Each wind file carries its own credit line (ERA5 from Copernicus, served by Open-Meteo, CC BY 4.0). Keep that line when copying the file anywhere.
