# License Change to AGPL-3.0

## Status

Accepted. Supersedes [ADR 001 - Licensing](001-licensing.md).

## Decision

MPL-2.0 -> AGPL-3.0.

## Context

MPL-2.0 is a weak, file-level copyleft. Modifications to individual files must be shared back,
but the project can be incorporated into larger proprietary works without sharing the surrounding
code. That's not what we're after. When someone makes money using this project's code, we want them
to share their modifications back with the community.

Of course, self-hosters should be allowed to keep their personal configurations private.

In the future, we may offer a totally optional cloud backup service of the Sturmfeste.
As we are the copyright holders, AGPL-3.0 is compatible with this through dual-licensing.
But we need a Contributor License Agreement (CLA) before accepting any external contributions.

The project is still early-stage and has no external contributions, so relicensing is still easy and straightforward.

## Consequences

- All existing and new source files must be licensed under AGPL-3.0.
- Proprietary use of the code or closed-source services need a separate commercial license.
- A CLA must be established before accepting external contributions to preserve dual-licensing
  ability.
- Source file headers should include the AGPL-3.0 notice as recommended by the license.
