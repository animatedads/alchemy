/*
 * LibrarianModelClosureContract.cls
 *
 * Machine-readable closure declaration for deterministic Librarian evidence.
 * Artefact closure is hashed by LibrarianModelManifest / provider source manifest.
 * Object closure is frozen before an analyzer may be used by the v0.11 provider.
 */

::class LibrarianModelClosureContract public

::method contractVersion class
  return 'LIBRARIAN_MODEL_CLOSURE_CONTRACT_V011'

::method artefactRoles class
  roles=.Array~new
  roles~append('WORDNET_DATA_NOUN')
  roles~append('WORDNET_DATA_VERB')
  roles~append('WORDNET_DATA_ADJ')
  roles~append('WORDNET_DATA_ADV')
  roles~append('WORDNET_EXC_NOUN')
  roles~append('WORDNET_EXC_VERB')
  roles~append('WORDNET_EXC_ADJ')
  roles~append('WORDNET_EXC_ADV')
  roles~append('DBFILES_MEMBERSHIP_BASENAME_CONTENT_OR_EXPLICIT_SKIP')
  roles~append('LEXICON_CACHE_WHEN_CACHE_SOURCE_MODE')
  roles~append('TARGET_DEFINITIONS')
  roles~append('GAZETTEER_DEFINITIONS_OR_DECLARED_BUILTIN_MODE')
  roles~append('ANALYZER_CONFIGURATION')
  return roles

::method objectRoles class
  roles=.Array~new
  roles~append('LIBRARIAN_LEXICON')
  roles~append('LIBRARIAN_WORDS_AND_SENSE_ORDER')
  roles~append('LIBRARIAN_EXCEPTIONS_AND_SOUNDEX_INDEX')
  roles~append('LIBRARIAN_RELATION_GRAPH')
  roles~append('LIBRARIAN_GRAMMAR')
  roles~append('LIBRARIAN_TARGET_MODEL')
  roles~append('LIBRARIAN_TARGET_TERMS_AND_EXPANSION_PATHS')
  roles~append('LIBRARIAN_GAZETTEER')
  return roles

::method canonicalText class
  text=self~contractVersion || '0a'x
  roles=self~artefactRoles
  roles~sort
  do role over roles
    text=text || 'ARTEFACT|' || role || '0a'x
  end
  roles=self~objectRoles
  roles~sort
  do role over roles
    text=text || 'OBJECT|' || role || '0a'x
  end
  text=text || 'PUBLICATION_RULE|ARTEFACT_MEMBERSHIP_FROZEN;FILE_CONTENT_REHASHED_LIVE' || '0a'x
  text=text || 'ANALYZER_RULE|FRESH_FROZEN_ANALYZER_PER_PROVIDER_EXECUTION' || '0a'x
  text=text || 'MUTATION_RULE|MUTATION_REQUIRES_NEW_MODEL_IDENTITY' || '0a'x
  return text

::method hash class
  return .AlgorithmDigest~sha256Text(self~canonicalText)

::requires '../algorithm/AlgorithmIntegrity.cls'
