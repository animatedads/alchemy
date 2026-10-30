# MAS application ABI — BASE-1 candidate

The S/370 application ABI, local-service ABI, and `mvs.alchemy/1` wire ABI are distinct contracts.
Public parameter blocks are caller-owned, fixed-width, versioned and explicitly length checked. Reserved input fields must be zero. Application pointers terminate at the local MAS boundary.

Stable return categories are: 0 success; 4 warning/qualification; 8 caller/request error; 12 service/transport/protocol unavailable; 16 authority/policy rejection; 20 MAS integrity/internal failure. `BASE/MACLIB/MASRC.asm` is authoritative for the currently assigned reasons.

Application handles are opaque 32-bit tokens. They are not protocol remote handles, Alchemy identities, provider handles, or addresses. Generation/slot encoding is an implementation option and is not public ABI.
