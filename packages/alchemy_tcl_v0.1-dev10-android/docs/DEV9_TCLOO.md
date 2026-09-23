# dev9 — TclOO authority

TclOO objects remain Tcl command identities in the resident interpreter. Rexx delegates class queries and method dispatch to Tcl rather than manufacturing a Rexx class hierarchy. Qualification covers live state, class method amendment after projection, Tcl rename, and Tcl destruction/absence.

The native one-string-argument call is deliberately bounded. A Tcl_Obj/list-safe general value codec and AlchemyForeignObject UNKNOWN composition are later layers.
