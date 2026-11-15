# Testimony cases

Each folder is the bank case with one thing changed. `expect.txt` lists the verdict each proposition must get. Only the record and the added witness differ between cases; the three statements are the same.

- main: as given, with the arrest record (Liam arrested outside the bank, 3:20).
- a: no record. Testimony only.
- b: the record puts Liam outside the supermarket instead. Liam's own account is then the impeached one.
- c: adds a witness with no stake (Sara, who works at the bank) who saw Noah there at 3:15.
- d: the record names Noah, not Liam.

Run: `sh testimony_cases/run.sh`
