"""Portable perception eligibility projection; advisory only, not execution authority."""
from dataclasses import dataclass
from typing import FrozenSet

@dataclass(frozen=True)
class Requirement:
    operation: str
    source_digest: str
    model_digest: str
    region: str
    principal: str
    checkpoint_schema: str
    needs_gpu: bool = False
    def __post_init__(self):
        if not all((self.operation,self.source_digest,self.model_digest,self.region,self.principal,self.checkpoint_schema)):
            raise ValueError("incomplete pinned requirement")

@dataclass(frozen=True)
class Witness:
    operations: FrozenSet[str]
    model_digests: FrozenSet[str]
    regions: FrozenSet[str]
    principals: FrozenSet[str]
    checkpoint_schemas: FrozenSet[str]
    can_materialise: bool
    can_commit: bool
    gpu: bool = False

def eligible(work: Requirement, node: Witness) -> bool:
    """Conservative capability match. Never grants a lease or dispatches."""
    return (work.operation in node.operations
            and work.model_digest in node.model_digests
            and work.region in node.regions
            and work.principal in node.principals
            and work.checkpoint_schema in node.checkpoint_schemas
            and node.can_materialise and node.can_commit
            and (not work.needs_gpu or node.gpu))
