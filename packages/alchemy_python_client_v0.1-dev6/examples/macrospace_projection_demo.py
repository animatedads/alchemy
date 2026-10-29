"""Demonstrate using a pre-existing retained native object without fake RPC.

The caller MUST supply the actual native _rexxpython_poc module and an already
created projected Rexx object. No demonstration object is fabricated here.
"""
from alchemy_python import Macrospace


def project_existing(native, retained_projection):
    objects = Macrospace(native)
    Animal = objects.virtual_class("Animal", {"describe": "describe", "speak": "speak"})
    animal = objects.adopt(Animal, retained_projection)
    return animal.describe()  # The native bridge owns dispatch, re-entry and lifetime.
