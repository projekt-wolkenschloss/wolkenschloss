# Secret Management Tools in Wolkenschloss

<!--
Some general info about decision records:

- Each DR should be about one decision, not multiple.
- DRs should be kept immutable. For changes, supersede with another DR

For a reason why we use decision records:

https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions

How to use the template:

1. Copy the file
2. Fill out all sections
-->

## Status

<!--
What is the status of the decision, such as proposed, accepted, rejected, deprecated, superseded, etc.?
-->

2026-03-14: Accepted

## Decision

<!--
What is the change that we're proposing and/or doing?
-->

We use ssh key-pairs as device and operator secrets. We use age for secret encryption.

We use SOPS (Secret OPerationS) and sops-nix to manage the secrets for the hosts.

## Context

<!--
What is the issue that we're seeing that is motivating this decision or change?

Explain the reasons for doing the particular decision. This can include

- the overall context,
- pros and cons of various potential choices
- feature comparisons
- cost/benefit discussions
- assumptions
- constraints
- personal bias and feelings
- team structure and skills

and more.

Reference existing DRs, if available
-->

I've read a blog of Michael Stapleberg (<https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/#usage-example-samba-userspasswords>) and read the comparison of <https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes>

Seems that agenix and sops-nix are the most popular as of late 2025. Because reliability and maintainability are in the top five quality goals, popularity weighs a lot.

Furthermore, sops-nix can use age with ssh keys for encryption of files, meaning devs and machines only need access to their ssh key-files to encrypt and decrypt the secrets. I claim that we (devs and ops) take good care of ssh keys and ssh is an old, widely known and reliable technology.

Our requirements for secret management are (late 2025):

- Source of truth for secrets is the git repo
- Secrets are deployed automatically with everything else
- Keys for the secrets are bound to the operators and hosts

Looking ahead, we might switch to a zero-trust approach using SPIFFE, node and workload attestation. Then, I suspect the current approach will be obsolete. This would also help getting the project ready for non-technical people. We cannot expect them managing secret material like env files or ssh keys. But until then, we need something usable and widely known.

## Consequences

<!--
Explain what follows from making the decision. This can include the effects, outcomes, outputs, follow ups, and more.

What becomes easier or more difficult to do because of this change?

What existing decisions and decision records are affected?
-->

The secret management process is tightly integrated into operations and if we need to change that, we have a lot of work before us.
