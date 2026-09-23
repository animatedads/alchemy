from objects import RexxStem

stem = RexxStem.new()

print("stem-NAME:", stem["NAME"])
print("stem-SPECIES:", stem["SPECIES"])
print("stem-compound-FOOD.1:", stem["FOOD.1"])
assert stem["NAME"] == "Monty"
assert stem["SPECIES"] == "parrot"
assert stem["FOOD.1"] == "biscuit"
assert stem["FOOD.2"] == "seed"

# Python mutates the retained Rexx Stem rather than a copied dict.
stem["NAME"] = "Polly"
stem["FOOD.3"] = "apple"

print("python-wrote-NAME:", stem["NAME"])
print("python-wrote-FOOD.3:", stem["FOOD.3"])
assert stem["NAME"] == "Polly"
assert stem["FOOD.3"] == "apple"

print("PYTHON <-> REAL OOREXX STEM POC PASS")
