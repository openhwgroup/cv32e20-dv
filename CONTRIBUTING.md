<!--
Copyright 2026 OpenHW Foundation
SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
-->

# Contributing
New Contributors are always welcome. Start by having a look at the **README**, and review open [Issues](https://github.com/openhwgroup/cv32e20-dv/issues) with a "Good First Issue" label.

## Contributor Agreement
Most Contributors are [members](https://www.openhwgroup.org/membership/) of the
OpenHW Foundation and participate in one or more [Technical Task Groups](https://www.openhwgroup.org/working-groups/).
Membership is strongly encouraged, but not required.  Contributors must be
covered by the terms of the [Eclipse Contributor Agreement](https://www.eclipse.org/legal/ECA.php)
(for individuals) **or** the [Eclipse Member Committer and Contributor Agreement](https://www.eclipse.org/legal/committer_process/EclipseMemberCommitterAgreement.pdf)
(for employees of Member companies). The ECA/MCCA provides a legal
framework for a Contributor's technical contributions to the OpenHW Foundation,
including provisions for grant of copyright license and a Developer
Certificate of Origin on contributions merged into OpenHW Foundation repositories.
<br><br>
All pull-requests to OpenHW Foundation git repositories should be signed-off using the
`--signoff` (or `-s`) option to the git commit command (see below), although this is no longer strictly necessary.

## Licensing
CV32E20-DV is an open source project, using permissive licensing.
Our preferred license is [Solderpad](https://github.com/openhwgroup/core-v-verif/blob/master/LICENSE.md), and we accept most well known permissive licenses.
If you are submitting a new file that does not yet have a copyright header please add the following [SPDX](https://spdx.dev/) header:
```
// Copyright (c) <year> <organization>
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
```
In the above header, "organization" should either be your employer, your institution or yourself:
- If you are being paid to make a contribution on behalf of an employer, then the copyright will be held by your employer.
- If an educational institution is supporting your contribution (for example, by providing access to computer and/or tools), then the copyright should be assigned to your educational institution.
- Otherwise, you may assign the copyright to yourself.  You may use your full name or email address as you see fit.

## The Mechanics
1. [Fork](https://help.github.com/articles/fork-a-repo/) the [cv32e20-dv](https://github.com/openhwgroup/cv32e20-dv) repository
2. Clone repository: `git clone https://github.com/[your_github_username]/cv32e20-dv`
3. Checkout the correct branch reflecting the nature of your contribution.  Nearly all contributions should target a _dev_ branch.
4. Create your feature branch: `git checkout -b <my_branch>.`<br> Please uniquify your branch name.  See the [Git Cheats](https://github.com/openhwgroup/core-v-verif/blob/master/GitCheats.md) for a useful nominclature.
5. Commit your changes: `git commit -m 'Add some feature' --signoff`
6. Push feature branch: `git push origin <my_branch>`
7. Submit a [pull request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork).
8. If known, it is advisable to select one or more appropriate reviewers for your PR.
