"""Optional explicit integration with existing Alchemy Python macrospace v0.31.7.

This SDK never bundles, reimplements, or secretly imports the native extension.
"""
from __future__ import annotations

from typing import Any, Mapping
from .errors import NativeBridgeUnavailable
from .virtual import LiveRexxObject, VirtualRexxClassFactory


class Macrospace:
    """Bind externally supplied, version-qualified _rexxpython_poc implementation.

    Bootstrap/path resolution is owned by the existing bridge/package registry;
    callers must initialise and project objects through that authority.
    """

    def __init__(self, native_module: Any) -> None:
        if native_module is None:
            raise NativeBridgeUnavailable("pass explicitly qualified native Python macrospace module")
        self.native = native_module

    def virtual_class(self, rexx_class_name: str, method_map: Mapping[str, str]) -> type[LiveRexxObject]:
        return VirtualRexxClassFactory.make(rexx_class_name, method_map)

    def adopt(self, virtual_class: type[LiveRexxObject], retained_projection: Any) -> LiveRexxObject:
        if not issubclass(virtual_class, LiveRexxObject):
            raise TypeError("expected a virtual Rexx class")
        return virtual_class(retained_projection)
