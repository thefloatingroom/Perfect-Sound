# Perfect Sound — adding a new script

Five-minute checklist for adding any new commercial script. Repeat for
every new product. Each script lives in **three places** that must stay
in sync: the public stub, the index, and the encrypted bundle in D1.

## Per-script checklist

Picking `<slug>` for the example. Use lowercase, no spaces (e.g. `levels`,
`auto-trim`, `bus-router`).

### 1. Write the script normally

Just a `.lua` file on your Mac. Use full comments, helpful names — write it
like any internal tool. Don't think about encryption yet.

### 2. Strip + obfuscate

```bash
# 2a. Strip comments + blank lines (built into the project)
node tools/build-bundle.mjs ~/path/to/<slug>.lua > /tmp/<slug>.stripped.lua

# 2b. Obfuscate. Either:
#     - Paste /tmp/<slug>.stripped.lua into https://luaobfuscator.com (free,
#       online, fast)
#     - Run Prometheus locally (https://github.com/levno-710/Prometheus)
#       e.g. prometheus /tmp/<slug>.stripped.lua --preset Strong > /tmp/<slug>.obf.lua

# Use the obfuscated output for the next step.
```

### 3. Upload bundle via dashboard

1. Open `https://perfect-sound-api.khonnorsound.workers.dev/admin?key=<ADMIN_KEY>`
2. **Scripts → + Create Script**
   - Slug: `<slug>`
   - Name: `<Pretty Name>`
   - Version: `1.0.0`
   - Description: short one-liner
3. **Bundle** button on the new row → paste the obfuscated source → **Upload**
4. (Optional) Test the bundle is stored: `Scripts list` reload — `bundle_hash`
   should be set, not null.

### 4. Add the public stub

Create `stubs/<slug>.lua` in the public GitHub repo with this content
(copy from an existing stub and change the slug):

```lua
-- Perfect Sound - <Pretty Name>
-- Public stub. The actual implementation is delivered encrypted from the
-- licensing server only to authorized licenses. This file is harmless on
-- its own.
PERFECT_SOUND_RUN = "<slug>"
dofile(reaper.GetResourcePath() .. "/Scripts/PerfectSound/Core/loader.lua")
```

That's it. The stub is trivial on purpose — anyone can see it, but without a
license assignment in the backend, running it just shows "not_authorized".

### 5. Add the entry to `index.xml`

Inside the right `<category>` block (Editing / Tools), append a new
`<reapack>` block. Copy from an existing one and change name, file, slug
in source URL:

```xml
<reapack name="<slug>.lua" type="script" desc="<short description>">
  <metadata>
    <description><![CDATA[
<longer description that customers will see>
Requires a Perfect Sound license that includes <Pretty Name>.
    ]]></description>
  </metadata>
  <version name="1.0.0" author="Perfect Sound" time="<ISO timestamp>">
    <changelog><![CDATA[Initial release.]]></changelog>
    <source main="true" file="<slug>.lua">https://raw.githubusercontent.com/thefloatingroom/Perfect-Sound/main/stubs/<slug>.lua</source>
  </version>
</reapack>
```

Pick the right `<category>`:

- **Editing** — anything used during editing, recording, post-production
- **Tools** — internal/utility scripts

### 6. Validate locally

```bash
xmllint --noout index.xml && echo "XML OK"
```

If it doesn't say `XML OK`, fix the XML before pushing.

### 7. Commit and push

```bash
git add stubs/<slug>.lua index.xml
git status   # sanity check
git commit -m "add <slug> v1.0.0"
git push
```

### 8. Assign the script to licenses

For each customer who has bought it:

1. Dashboard → **Licenses** → row of the customer → **Scripts**
2. Tick `<slug>` → **Save**

### 9. Customer side

When the customer next opens REAPER:

1. **Extensions → ReaPack → Synchronize packages**
2. Browse Packages → find `<slug>` under the right category → **Install** → Apply
3. Run from Action List

If they already have a session, no login prompt. If not, the loader
prompts once per device.

## Updating a script (new version)

Same steps but lighter:

1. Edit + obfuscate again
2. **Scripts → row → Bundle → paste new source → Upload** (overwrites previous)
3. Bump version in `index.xml` and the `time=`, push

ReaPack picks up the new version on next Synchronize.

## Tracking deployments

Use the dashboard's **Analytics** tab to see:

- `package_served` — when a customer fetched a script
- `package_unauthorized` — someone tried to fetch without authorization
- `login_ok` / `login_fail` — auth flow

## Common gotchas

- **`loader.lua` got a path change** → update `Scripts/PerfectSound/Core/loader.lua`
  in every stub and announce it as a breaking change. Don't forget to bump
  the loader version too.
- **Customer says "I see the package but it does nothing"** → check Analytics
  for their token; likely missing assignment in `license_scripts`.
- **Customer says "I get device_mismatch"** → use the **Unbind** action
  in their license row, then they re-login on the new machine.
- **Forgot to push the stub but already updated the index** → ReaPack will
  fail to install with 404. Push the stub immediately.
- **Updated the bundle but the customer still gets the old behavior** → the
  loader has no caching of bundles. They must just re-run the action;
  it will fetch the new bundle. If they have a session token cached, that's
  fine — sessions don't cache bundles.
