# Architecture

Core Banking answers whether a customer's account may be debited/credited. Teller Till answers whether physical cash is in the custody of a particular teller/till and whether an exactly counted bundle may leave or enter that custody. Neither authority substitutes for the other.

A future teller-cash orchestrator must therefore use write-ahead state to coordinate both sides and explicitly represent incomplete outcomes requiring reconciliation.
