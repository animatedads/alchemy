# Dev9 controller approvals qualification

Runtime: Open Object Rexx 5.3.0 r13196 (user-supplied extracted Debian package).

The controller/approval slice was executed with Alchemy Object RTOSecurityManager SHA-256 `d053a95cd09f893996249ba636ab5f9387c4b4e8e6ba0fc0638061e24da53fc0` temporarily staged for qualification.

Runtime suite result:

- PASS test_controller_approvals
- PASS test_customer_sales_order_replication
- PASS test_directory_active_members
- PASS test_document_definitions_views
- PASS test_document_script_carriage
- PASS test_field_sources_external_documents
- PASS test_oorexx_directory_semantics
- PASS test_two_node_replicate
- tests=8 failures=0

The controller proof verifies node-local SecurityManager injection, sandbox execution of travelling OnSubmit source, first-class signed approval items, detached approval replication, safe auto-approval, failed-check PENDING APPROVAL state, and blocked/audited ADDRESS SYSTEM. Referral/team-leader routing is not yet implemented in this checkpoint.
