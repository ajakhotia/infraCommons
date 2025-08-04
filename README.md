# infraCommons
Contains a set of common files that are used across projects. This repository acts
as the main version of the said files. Each client project makes a copy of the files that it needs.
The client projects also implement a CI test that continuously compares this repository's main branch
with a checkout of the client repository. The CI test succeeds if the intersection of the files between
the checkout of the client repository and this repository's main branch is congruent.

i.e., The files that exist in both (matched using paths relative to the root) MUST be EXACTLY the same.
