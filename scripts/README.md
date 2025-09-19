# DEP Setup Scripts

This directory contains scripts to help set up DEP customizations on fresh chatwoot clones.

## apply_dep_customizations.sh

### Purpose
Applies all DEP-specific customizations from https://github.com/amrhym/dep onto a fresh chatwoot clone from https://github.com/chatwoot/chatwoot.

### Quick Start
```bash
# In a fresh chatwoot clone:
git clone https://github.com/chatwoot/chatwoot.git my-chatwoot
cd my-chatwoot

# Copy this script into the clone, then run it:
curl -o scripts/apply_dep_customizations.sh https://raw.githubusercontent.com/amrhym/dep/develop/scripts/apply_dep_customizations.sh
chmod +x scripts/apply_dep_customizations.sh
./scripts/apply_dep_customizations.sh
```

### What it does
1. **Adds remotes**: Ensures both `origin` (chatwoot) and `dep` (your fork) remotes exist
2. **Fetches latest**: Gets the most recent refs from both repositories
3. **Creates branch**: Makes a new branch based on `origin/develop` (or your specified base)
4. **Generates patch**: Creates a binary-capable patch containing all differences between upstream and your DEP fork
5. **Applies changes**: Uses 3-way merge to apply the patch (safer against upstream drift)
6. **Commits**: Creates a commit with the applied DEP customizations

### Options
```bash
# Dry run - check if patch applies without making changes
./scripts/apply_dep_customizations.sh --dry-run=true

# Use a specific target branch name
./scripts/apply_dep_customizations.sh --target-branch=my-dep-setup

# Apply onto a different base (e.g., specific tag)
./scripts/apply_dep_customizations.sh --base-ref=v4.6.0

# Keep the generated patch file for inspection
./scripts/apply_dep_customizations.sh --keep-patch=true

# Use environment variables instead
BASE_REF=origin/develop TARGET_BRANCH=dep/customized ./scripts/apply_dep_customizations.sh
```

### Example Output
```
[INFO] Adding remote 'dep' -> https://github.com/amrhym/dep.git
[INFO] Fetching latest from origin and dep ...
[INFO] Creating and switching to branch: dep/customized-20241219113000 (base: origin/develop)
[INFO] Generating patch: origin/develop..dep/develop -> patches/dep-customizations.ABC123.patch
[INFO] Applying patch (3-way merge, index update) ...
[INFO] Patch applied successfully. Committing changes ...
[INFO] Summary of changes:
 87 files changed, 5426 insertions(+), 3110 deletions(-)
[INFO] Done. Current branch: dep/customized-20241219113000
```

### Use Cases

#### New Team Member Setup
```bash
git clone https://github.com/chatwoot/chatwoot.git
cd chatwoot
# Get the script from your DEP repo
curl -o scripts/apply_dep_customizations.sh https://raw.githubusercontent.com/amrhym/dep/develop/scripts/apply_dep_customizations.sh
chmod +x scripts/apply_dep_customizations.sh
./scripts/apply_dep_customizations.sh
```

#### Testing DEP Changes Against Latest Upstream
```bash
# In existing repo
git fetch origin
./scripts/apply_dep_customizations.sh --base-ref=origin/develop --target-branch=test-dep-latest
```

#### Creating Hotfix Branch with DEP Customizations
```bash
./scripts/apply_dep_customizations.sh --base-ref=v4.5.2 --target-branch=hotfix/v4.5.2-dep
```

### Requirements
- Git available in PATH
- Run inside a git work tree (typically a chatwoot clone)
- Internet access to fetch from both remotes

### Troubleshooting

#### Patch Conflicts
If upstream has changed significantly, the 3-way merge may fail:
```
[WARN] 3-way apply failed. Attempting --reject mode to write .rej hunks ...
[WARN] Conflicts were produced (.rej files). Please resolve manually, then stage and commit.
```
This creates `.rej` files showing conflicts. Resolve them manually, then:
```bash
git add .
git commit -m "Apply DEP customizations from dep/develop onto origin/develop"
```

#### Missing Remotes
```
[ERR ] Missing 'origin' remote. Please add the chatwoot upstream as 'origin' and rerun.
```
Add the upstream remote:
```bash
git remote add origin https://github.com/chatwoot/chatwoot.git
```

#### No Changes to Apply
```
[INFO] No differences found between origin/develop and dep/develop. Nothing to apply.
```
This means your DEP fork is up-to-date with upstream - no customizations to apply.