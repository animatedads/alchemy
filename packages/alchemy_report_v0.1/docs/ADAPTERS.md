# Domain adapters are not the report kernel

AlchemyReport.cls knows claims, bindings, trails, seal and point index.
It does not know NOTAMs, PNRs, collateral or policy schedules.

Load only the adapter files the application needs.
sourceKind is an open token. Core transform registry starts empty.
