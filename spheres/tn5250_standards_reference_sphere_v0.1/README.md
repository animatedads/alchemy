# TN5250 Standards and Reference Navigation sphere v0.1

Separate reference sphere for the Terminal Machine / TN5250 project. It intentionally does **not** duplicate the implementation/architecture sphere. Its job is to tell an LLM or engineer which primary source governs a question, where to open it, how to navigate it with Gopher, and which source-version relationships must not be confused.

Core hierarchy: SA21-9247-6 for the 5250 workstation data stream; RFC 1205 for base TN5250 and its SA21-9247-6 corrections/enhancements; RFC 4777 for TN5250E enhancements; generic Telnet RFCs for their individual option semantics; IBM Documentation for current IBM i operational behaviour.

The archival SA21-9247-6 link is a locator to an IBM publication scan, not a claim that the archive is the publication authority.
