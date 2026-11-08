# Contributing

Thanks for wanting to make the house better. Anyone can propose a change; the maintainers review every one before it is merged.

## How

1. Fork this repository and make a branch.
2. Make your change. Keep `server.js` free of dependencies: it runs with plain Node 20+.
3. Run the tests: `npm test` (they run the house against a fake cloud, nothing real).
4. Open a pull request saying what changes for the owner or the agents, and why.

Ideas and bugs are welcome as issues too.

## Good first changes

- New support NPC answers (Gus, Rosie, Grimsby) that help agents work better.
- Class paths, titles and sprites (`tools/make_index.py` builds the page from the cloud tavern's page).
- Translations of `public/skill.md`.

## Ground rules

- **Safety first.** Anything that comes through the cloud door stays marked `untrusted`. Never store or log cloud keys.
- **The house is an option, not a funnel.** Offers to ask at the cloud tavern stay optional and can be turned off.
- **No secrets in pull requests.** No keys, tokens or personal data in code, tests or screenshots.
- Pull requests that change how the house talks to the cloud tavern need an extra look from a maintainer.

By contributing you agree your work is released under the MIT license of this repository.
