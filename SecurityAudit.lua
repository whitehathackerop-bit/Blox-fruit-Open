-- ============================================================
-- SECURITY AUDIT LOGGER
-- SERVER ONLY | ModuleScript
-- บันทึก Log ทุกเหตุการณ์ด้านความปลอดภัย
-- ============================================================

local SecurityAudit = {}

local MAX_LOGS = 500
local logs     = {}
local nextId   = 0

local function clean(value, maxLength)
    return tostring(value or "N/A"):sub(1, maxLength or 200)
end

function SecurityAudit.Record(player, eventType, details)
    nextId += 1

    local userId = 0
    if typeof(player) == "Instance" and player:IsA("Player") then
        userId = player.UserId
    end

    local entry = {
        Id      = nextId,
        Time    = os.time(),
        UserId  = userId,
        Event   = clean(eventType, 50),
        Details = clean(details, 200),
    }

    table.insert(logs, entry)
    if #logs > MAX_LOGS then
        table.remove(logs, 1)
    end

    local critical = eventType == "PERMISSION_DENIED"
        or eventType == "SECURITY_ERROR"
        or eventType == "INVALID_REQUEST"
        or eventType == "AUTHENTICATION_FAILED"
        or eventType == "ANTICHEAT_VIOLATION"
        or eventType == "ADV_ANTICHEAT"
        or eventType == "BANNED_JOIN"

    if critical then
        warn("[AUDIT]", entry.Id, entry.UserId, entry.Event, entry.Details)
    else
        print("[AUDIT]", entry.Id, entry.UserId, entry.Event)
    end

    return entry.Id
end

function SecurityAudit.GetRecent(limit)
    limit = math.clamp(math.floor(tonumber(limit) or 50), 1, 100)
    local result = {}
    local first  = math.max(1, #logs - limit + 1)
    for i = first, #logs do
        local e = logs[i]
        table.insert(result, {
            Id      = e.Id,
            Time    = e.Time,
            UserId  = e.UserId,
            Event   = e.Event,
            Details = e.Details,
        })
    end
    return result
end

function SecurityAudit.GetAll()
    local result = {}
    for i = 1, #logs do
        local e = logs[i]
        table.insert(result, {
            Id      = e.Id,
            Time    = e.Time,
            UserId  = e.UserId,
            Event   = e.Event,
            Details = e.Details,
        })
    end
    return result
end

function SecurityAudit.Count()
    return #logs
end

function SecurityAudit.Clear()
    logs   = {}
    nextId = 0
end

return SecurityAudit
