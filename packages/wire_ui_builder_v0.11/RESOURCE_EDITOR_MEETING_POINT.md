# Wire UI Builder v0.11 — Resource Editor Meeting Point

## Product boundary

The Resource Editor is a separate developer tool/product. It authors, versions, validates and publishes fixed resources. Wire UI Builder consumes those resources by exact immutable reference only.

The Builder must never grow:

- a free-text display-copy field;
- `Label: [type some text]`;
- an inline paragraph/headline/caption editor;
- an `Insert image` / upload-image control;
- a file-path or URL escape hatch that bypasses resource identity;
- embedded resource bytes in Builder project/release data.

If presentation content is needed, it is created in the Resource Editor first and then selected/referenced in Builder.

## Builder-side resource reference contract

Builder currently consumes this exact identity through `WireUIResourceRef`:

```text
resourceId       stable semantic resource identity
version          exact immutable version
contentAddress   exact content address supplied by resource authority
resourceClass    TEXT | GRAPHIC | AUDIO | VIDEO | STRUCTURED | COMPOUND | OTHER
locale           optional locale identity
```

There is no implicit `latest`. A published Builder release pins the exact reference supplied by the resource system.

Projection binding is semantic:

```text
resourceBindings[]
    role          e.g. PRIMARY_CONTENT, TERMS, ICON, ILLUSTRATION
    resourceRef   exact WireUIResourceRef
    required      boolean
```

The role describes why the projection uses the resource. It does not describe a DOM node, image element, Swing widget or file implementation.

## Resource Editor responsibilities

The Builder deliberately does not define the Resource Editor's internal implementation, but the resource authority is expected to own the things the Builder must not own: resource bytes/content, provenance, version lifecycle, locale/variant management, accessibility representations, legal/content approval state and publication/content addressing.

A resource may itself be graphical or compound. For example, a pre-approved credit-card offer card can be one graphical/compound resource. Builder references the resource identity; it does not insert a PNG. A Terms and Conditions presentation is likewise a resource; the Builder never contains the terms as arbitrary copy.

## Conditional presentation

Conditional Builder placements still reference resources normally. The resource does not decide whether it appears. Authoritative facts/decisions feed Builder `CONDITION` artifacts; presentation policy arbitrates; an admitted projection then uses the exact resource ref.

```text
FACT / DECISION
      -> CONDITION
      -> conditional placement
      -> presentation arbitration
      -> admitted projection
      -> exact external resource ref
```

This keeps business eligibility, presentation policy and content/resource lifecycle as separate authorities.

## Future integration surface

A future Builder/Resource-Editor integration may provide resource search/browse/selection and validation of exact refs. That remains a lookup/binding surface. Editing a resource always opens/uses the Resource Editor; it never turns the Builder into the Resource Editor.
