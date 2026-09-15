# OurLadyAir Shannon — demo ticket groups (fictional)

Flight **OA 1541** DUB–STN 21 Aug 2026 07:35–08:50. A320 174Y.  
Ticket stock **607** (imaginary). Not valid for carriage. Not Ryanair.

Seat map: rows 1–30, `A B C | D E F`.

---

## GROUP 01 — together (family)

| Role | Name | DOB | Type | Seat | Ticket | Fare EUR |
|------|------|-----|------|------|--------|----------|
| **Lead** | Aoife Murphy MS | 1978-03-14 | A | 12A | 6071234567890 | 189.99 |
| | Sean Murphy MR | 1975-11-02 | A | 12B | 6071234567891 | 189.99 |
| | Noah Murphy MSTR | 2015-09-21 | C (10) | 12C | 6071234567892 | 94.99 |
| | Rosa Murphy MISS | 2018-02-03 | C (8) | 12D | 6071234567893 | 94.99 |
| | Baby Murphy MSTR | 2024-01-15 | INF (2) | lap | 6071234567894 | 25.00 |

PNR `OLA7K2M`. Bags: 2×20kg hold. Shannon: alcohol blocked for C/INF; custody group intact.

---

## GROUP 02 — split stag (five PNRs)

| Role | Name | Seat | PNR | Ticket | Fare | Bag |
|------|------|------|-----|--------|------|-----|
| **Lead** | Declan Kelly | **3A** | OLA8P1Q | 6071234567901 | 39.99 | 10kg |
| | Cian Walsh | **18F** | OLA8P2R | 6071234567902 | 44.99 | none |
| | Paddy Byrne | **7C** | OLA8P3S | 6071234567903 | 29.99 | 20kg |
| | Mick Dunne | **24A** | OLA8P4T | 6071234567904 | 59.99 | 10kg |
| | Tom Foley | **11E** | OLA8P5U | 6071234567905 | 19.99 | none |

Scatter 3A / 7C / 11E / 18F / 24A. Pitch reserved seats together / priority — all adults.

---

## GROUP 03 — together (teen in party)

| Role | Name | DOB | Seat | Ticket | Fare |
|------|------|-----|------|--------|------|
| **Lead** | Amaka Okafor MS | 1985-07-19 | 15C | 6071234567910 | 79.99 |
| | Chidi Okafor MR | 1983-09-04 | 15D | 6071234567911 | 79.99 |
| | Ife Okafor MISS | **2010-03-12 (16)** | 15E | 6071234567912 | 59.99 |

PNR `OLA9C3W`. Beer **BLOCKED** for Ife even if she asks.

---

## GROUP 04 — split family (EpiPen bait)

| Role | Name | Age | Seat | PNR | Ticket | Notes |
|------|------|-----|------|-----|--------|-------|
| **Lead** | Bridget Nolan MRS | 70 | **4F** | OLAA1X1 | 6071234567920 | WCHR |
| | Lily Nolan MISS | 9 | **22B** | OLAA1X2 | 6071234567921 | SSR MEDA EpiPen + 10kg (may gate-check) |
| | Finn Nolan MSTR | 6 | **29C** | OLAA1X3 | 6071234567922 | no bag |

Custody UNKNOWN until cabin-stay guaranteed. Sales extras blocked on Lily until resolved.

---

## GROUP 05 — together (clean adults)

| Role | Name | DOB | Seat | Ticket | Fare |
|------|------|-----|------|--------|------|
| **Lead** | Sarah Haddad MS | 1988-11-25 | 6A | 6071234567930 | 129.99 |
| | Jennifer Stewart MS | 1987-03-03 | 6B | 6071234567931 | 129.99 |

PNR `OLAB2Y9`. 2×10kg priority already. FP VI …4411. Age facts present → beer/crisps admissible *after* verify.

---

## GROUP 06 — school fragment (partial together)

| Role | Name | Age | Seat | Ticket | Fare |
|------|------|-----|------|--------|------|
| **Lead** | Helen Brown MS (teacher) | adult | **8C** | 6071234567940 | 49.99 |
| | Aoife Quinn MISS | 14 | **8D** | 6071234567941 | 19.99 |
| | Conor Reilly MSTR | 15 | **27A** | 6071234567942 | 19.99 |
| | Maya Keane MISS | 12 | **28F** | 6071234567943 | 19.99 |

PNR `OLAC4Z0`. 8C–8D together; 27A/28F dumped. Alcohol blocked for all `C`. Offer seat-together, not bar.

---

## GROUP 07 — no seats bought (auto-spread)

| Role | Name | Allocated if they skip seats | PNR | Ticket | Fare |
|------|------|------------------------------|-----|--------|------|
| **Lead** | Declan MacLeod MR | **2A** | OLAD5K1 | 6071234567950 | 9.99 |
| | Noor Robertson MS | **16E** | OLAD5K2 | 6071234567951 | 9.99 |
| | Susan Okafor MS | **25C** | OLAD5K3 | 6071234567952 | 9.99 |

SSR `NSST` = seat not purchased. Shannon: those allocations will not sit together; sell a block.

---

## Transaction fields (every ticket)

- Issuing carrier / stock: OA / 607  
- Issue date on coupon (varies 12–21 Aug 26)  
- Sector: OA1541/21AUG DUBSTN  
- Fare currency EUR, one-way  
- Pax type A / C / INF  
- Seat SSR or NSST  
- Bag: NONE / 10KG / 20KG  
- Optional: FP, MEDA, INFT, MAAS  

## Shannon / HardWorld hooks

| Group | Seat story | Legal/HW facts |
|-------|------------|----------------|
| 01 | block 12A–D | minors + infant |
| 02 | scattered adults | sell together |
| 03 | block 15C–E | 16-year-old alcohol block |
| 04 | 4F / 22B / 29C | EpiPen + split custody |
| 05 | 6A–B | adult sale path |
| 06 | 8CD + tail | school minors |
| 07 | 2A / 16E / 25C | punish no-seat purchase |
