/* cog_semantic_demo.rex
   A small native registration surface based on real Cog recipe families.
*/

parser = .SymbolicNLPParser~new

parser~registerConcept("LIST", "VERB", "LIST|SHOW")
parser~registerConcept("COPY", "VERB", "COPY|DUPLICATE")
parser~registerConcept("EXTRACT", "VERB", "EXTRACT|UNPACK")
parser~registerConcept("DIRECTORY", "NOUN", "DIRECTORY|FILES|WORKSPACE")
parser~registerConcept("FILE", "NOUN", "FILE|DOCUMENT")
parser~registerConcept("ARCHIVE", "NOUN", "ARCHIVE|ZIP")

parser~registerSemanticIntent("LIST_DIR_CURRENT", "LIST", "DIRECTORY", "CURRENT DIRECTORY|WORKING DIRECTORY", 90)
parser~registerSemanticIntent("LIST_DIR_PATH", "LIST", "DIRECTORY", "", 95)
parser~registerSlot("LIST_DIR_PATH", "PATH", "IN", "REST", 1)

parser~registerSemanticIntent("COPY_FILE", "COPY", "FILE", "", 90)
parser~registerSlot("COPY_FILE", "SOURCE", "FROM", "PHRASE", 1, "TO")
parser~registerSlot("COPY_FILE", "DESTINATION", "TO", "REST", 1)

parser~registerSemanticIntent("EXTRACT_ZIP_ARCHIVE", "EXTRACT", "ARCHIVE", "ZIP ARCHIVE", 70)
parser~registerSlot("EXTRACT_ZIP_ARCHIVE", "ARCHIVE", "FROM", "PHRASE", 1, "TO|INTO")
parser~registerSlot("EXTRACT_ZIP_ARCHIVE", "DESTINATION", "TO|INTO", "REST", 1)

samples = .Array~of( -
  "list directory", -
  "list directory in src", -
  "copy file from README.md to backup/README.md", -
  "extract zip archive from build.zip into staging")

do i = 1 to samples~items
  request = samples~at(i)
  parsed = parser~parse(request)
  say request
  say "  status :" parsed~at("STATUS")
  say "  intent :" parsed~at("INTENT")
  say "  score  :" parsed~at("SCORE")
  say "  form   :" parsed~at("LOGICAL_FORM")
  say
end

::requires "../src/SymbolicNLP.cls"
