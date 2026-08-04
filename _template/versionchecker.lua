-- ============================================================
-- __NAME__ — VERSION CHECKER (server-side only)
--
-- Compares the version in fxmanifest.lua against the release manifest hosted at
-- github.com/Fixitfy/fivem-versionchecker and prints the result once, on start.
--
-- The manifest is a plain JSON array; order does NOT matter, versions are
-- compared numerically (1.0.10 is correctly newer than 1.0.9):
--
--   [
--     {
--       "version": "1.1.0",
--       "date": "2026-08-01",          -- optional
--       "critical": true,              -- optional, adds a [CRITICAL] tag
--       "changelog": [ "..." ],
--       "updateFiles": [ "server/main.lua", "fxmanifest.lua" ]
--     }
--   ]
--
-- Turn it off with Config.VersionCheck = false in __CONFIG__.
-- Other resources can read the result with:
--   exports['__NAME__']:GetVersionStatus()
-- ============================================================

local SCRIPT_ID   = '__NAME__'  -- manifest file name on GitHub; NOT the folder name
local MANIFEST_URL = ('https://raw.githubusercontent.com/Fixitfy/fivem-versionchecker/refs/heads/Fixitfy/%s.json'):format(SCRIPT_ID)

local MAX_ATTEMPTS = 3
local RETRY_DELAY  = 15000  -- ms between retries
local START_DELAY  = 4000   -- ms, lets the server finish booting so the banner is not buried
local WIDTH        = 66     -- box width

local RESOURCE = GetCurrentResourceName()
local CURRENT  = GetResourceMetadata(RESOURCE, 'version', 0)

-- state exposed to other resources: "uptodate" | "outdated" | "ahead" | "unknown" | "error" | "disabled"
local Status = { state = 'unknown', current = CURRENT, latest = nil, behind = 0 }

-- ===================== OUTPUT HELPERS =====================

local PREFIX = ('^3[^5%s^3]^0 '):format(RESOURCE)

local function say(msg)
    print(PREFIX .. msg .. '^0')
end

local function rule(color, left, right)
    say(color .. left .. string.rep('─', WIDTH) .. right)
end

-- Word-wraps long changelog lines so the box keeps its shape.
local function wrap(text, width)
    local out, line = {}, ''
    for word in tostring(text):gmatch('%S+') do
        if line == '' then
            line = word
        elseif #line + #word + 1 <= width then
            line = line .. ' ' .. word
        else
            out[#out + 1] = line
            line = word
        end
    end
    if line ~= '' then out[#out + 1] = line end
    return out
end

-- ===================== VERSION COMPARE =====================

-- "1.2.10-beta" -> { 1, 2, 10 }
local function parse(v)
    local parts = {}
    for num in tostring(v):gmatch('%d+') do
        parts[#parts + 1] = tonumber(num)
    end
    return parts
end

-- -1 = a older than b, 0 = equal, 1 = a newer than b
local function compare(a, b)
    local va, vb = parse(a), parse(b)
    for i = 1, math.max(#va, #vb) do
        local x, y = va[i] or 0, vb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- ===================== REPORTING =====================

local function reportUpToDate(latest)
    rule('^2', '┌', '┐')
    say(('^2├ ✅ Version %s — up to date'):format(CURRENT))
    rule('^2', '└', '┘')
end

local function reportAhead(latest)
    rule('^5', '┌', '┐')
    say(('^5├ ℹ️ Version %s is ahead of the latest release (%s) — development build'):format(CURRENT, latest))
    rule('^5', '└', '┘')
end

local function reportOutdated(latest, newer, listed)
    -- newer: entries strictly newer than CURRENT, oldest first
    local files, seen = {}, {}

    rule('^1', '┌', '┐')
    say(('^1├ ❌ Version %s is OUTDATED — latest is %s (%d release%s behind)')
        :format(CURRENT, latest, #newer, #newer == 1 and '' or 's'))

    if not listed then
        say(('^3├ ⚠ Version %s is not listed in the release manifest — showing every newer release.'):format(CURRENT))
    end

    say('^5├' .. string.rep('─', WIDTH))
    say('^3├ CHANGELOG')

    for i = 1, #newer do
        local entry = newer[i]
        local tag = entry.critical and ' ^1[CRITICAL]^3' or ''
        local date = entry.date and (' (' .. tostring(entry.date) .. ')') or ''
        say(('^3├ ^0Version %s%s%s'):format(entry.version, date, tag))

        for _, line in ipairs(entry.changelog or {}) do
            local wrapped = wrap(line, WIDTH - 8)
            for w = 1, #wrapped do
                say(('^3├ ^0   %s %s'):format(w == 1 and '•' or ' ', wrapped[w]))
            end
        end

        for _, file in ipairs(entry.updateFiles or {}) do
            if not seen[file] then
                seen[file] = true
                files[#files + 1] = file
            end
        end
    end

    if #files > 0 then
        say('^5├' .. string.rep('─', WIDTH))
        say('^3├ FILES TO UPDATE')
        for i = 1, #files do
            say('^2├ ^0   ' .. files[i])
        end
    end

    say('^5├' .. string.rep('─', WIDTH))
    say('^1├ Download the latest version from your Keymaster account.')
    rule('^1', '└', '┘')
end

local function reportError(msg)
    Status.state = 'error'
    rule('^1', '┌', '┐')
    say('^1├ ❌ Version check failed: ' .. msg)
    say(('^1├ Running version %s — verify it manually on Keymaster.'):format(CURRENT or 'unknown'))
    rule('^1', '└', '┘')
end

-- ===================== EVALUATE =====================

local function evaluate(data)
    local releases = {}
    for _, entry in ipairs(data) do
        if type(entry) == 'table' and entry.version then
            releases[#releases + 1] = entry
        end
    end

    if #releases == 0 then
        return reportError('release manifest is empty or malformed')
    end

    table.sort(releases, function(a, b) return compare(a.version, b.version) < 0 end)

    local latest = releases[#releases].version
    local diff   = compare(CURRENT, latest)

    Status.latest = latest

    if diff == 0 then
        Status.state = 'uptodate'
        return reportUpToDate(latest)
    elseif diff > 0 then
        Status.state = 'ahead'
        return reportAhead(latest)
    end

    local newer, listed = {}, false
    for _, entry in ipairs(releases) do
        local c = compare(entry.version, CURRENT)
        if c > 0 then
            newer[#newer + 1] = entry
        elseif c == 0 then
            listed = true
        end
    end

    Status.state  = 'outdated'
    Status.behind = #newer
    reportOutdated(latest, newer, listed)
end

-- ===================== FETCH =====================

local function fetch(attempt)
    PerformHttpRequest(MANIFEST_URL, function(status, body, _)
        if status == 200 and body and body ~= '' then
            local ok, data = pcall(json.decode, body)
            if not ok or type(data) ~= 'table' then
                return reportError('could not parse the release manifest (invalid JSON)')
            end
            return evaluate(data)
        end

        if attempt < MAX_ATTEMPTS then
            return SetTimeout(RETRY_DELAY, function() fetch(attempt + 1) end)
        end

        local reason = (status == 0 or status == -1 or status == nil)
            and 'could not reach GitHub (no connection / blocked outbound HTTP)'
            or ('GitHub returned HTTP %s'):format(tostring(status))
        reportError(('%s after %d attempts'):format(reason, MAX_ATTEMPTS))
    end, 'GET', '', { ['User-Agent'] = SCRIPT_ID .. '-versioncheck' })
end

-- ===================== BOOT =====================

CreateThread(function()
    if Config and Config.VersionCheck == false then
        Status.state = 'disabled'
        return
    end

    if not CURRENT or CURRENT == '' then
        return reportError("no version '...' entry found in fxmanifest.lua")
    end

    Wait(START_DELAY)
    fetch(1)
end)

exports('GetVersionStatus', function()
    return {
        state   = Status.state,
        current = Status.current,
        latest  = Status.latest,
        behind  = Status.behind,
    }
end)
