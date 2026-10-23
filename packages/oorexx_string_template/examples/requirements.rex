template = .StringTemplate~new("At ${time|iso}, ${sensor} measured ${value|unit:lux}.")
requirements = template~requirements
say "variables:" requirements~variables~toString("l", ", ")
say "formatters:" requirements~formatters~toString("l", ", ")
::requires "StringTemplate.cls"
