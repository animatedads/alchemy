# NoSQLServer owner handoff

Produce the next NoSQLServer candidate from the exact current v0.79 lineage.

Required scope:
- introduce preferred Foreign Runtime/libsqlite3 source access;
- retain the existing pure-ooRexx SQLite implementation as fallback and reference;
- provide explicit auto / foreign / native selection;
- expose selected implementation and fallback reason without leaking native handles;
- keep GeoPackage, SQL, federation, geometry, SRID and ST_* semantics owned by NoSQLServer;
- add differential tests between libsqlite3 and ooRexx for the common GeoPackage surface;
- prove library absence causes controlled fallback, not loss of GeoPackage capability;
- do not modify or vendor msqlshim.

Do not add GDAL/GEOS/PROJ until this SQLite dual-provider gate is green unless they are isolated behind disabled optional providers.

Return:
1. exact candidate ZIP;
2. SHA-256;
3. clean-extract manifest result;
4. full inherited suite result;
5. focused provider-selection/differential results;
6. declared capability matrix for both SQLite implementations.
