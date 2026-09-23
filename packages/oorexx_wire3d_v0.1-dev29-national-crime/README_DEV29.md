# Wire3D dev29 — national crime analytics view

First national COMPACT crime analytics presentation using the supplied Crime Area Analytics v0.3 contract.

Open `/national-crime.html` through the ooRexx HTTP-mode server. The view renders all 35,672 LSOA identities using renderer-LOD geometry and actual August/September 2025 street-crime counts from the supplied Police archive.

The generated JSON is a presentation fixture only. Runtime ingestion authority remains Crime Area Analytics / ooRexx CsvStream and NoSQLServer GIS. No CSV parser has been added to Wire.
