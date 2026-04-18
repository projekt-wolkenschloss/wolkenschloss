# Choosing a Software Forge for Wolkenschloss

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

We use Codeberg.org as software forge for the project and we mirror the code to Github.

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

Read <https://sfconservancy.org/GiveUpGitHub/>.

Realized, that right now is the best time to switch:

- No other contributors or community yet
- No CI/CD yet
- Microsoft is pushing AI on Github and I dont know how that will go
- I am not looking for drive-by contributions yet

The project is inspired by free and open source software and the philosophies behind it. So a potential maintainer that wants to join should align with that and therefore not care about the platform for might even have the same opinion.

## Consequences

<!--
Explain what follows from making the decision. This can include the effects, outcomes, outputs, follow ups, and more.

What becomes easier or more difficult to do because of this change?

What existing decisions and decision records are affected?
-->

Building a community, getting discovered and using CI/CD will probably be harder.
