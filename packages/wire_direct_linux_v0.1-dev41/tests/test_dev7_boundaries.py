from pathlib import Path
root=Path(__file__).resolve().parents[1]
a=(root/'rexx/WireAssessmentProjection.cls').read_text().lower()
s=(root/'rexx/WireEventSubjectProjection.cls').read_text().lower()
# Derived assessment is presentation-only here: no collection mutation/order/training/observation.
for forbidden in ('~sort','~reorder','~insert','~remove','~train','~observe','~outcome','~timer','~thread'):
    assert forbidden not in a, forbidden
# Subject extraction cannot acquire domain or evidence authority.
for forbidden in ('~imap','~fetch','~observe','~outcome','~assessment','~gtk','~glib','~timer'):
    assert forbidden not in s, forbidden
print('PASS dev7 negative boundaries: subject transport and assessment decoration do not acquire foreign authority')
