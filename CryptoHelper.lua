-- ============================================================
-- CRYPTO HELPER
-- SERVER ONLY | ModuleScript
-- HMAC-like + Timed Token + Log Chain
-- ============================================================

local CryptoHelper = {}

-- ============================================================
-- SECRET KEY — เปลี่ยนเองก่อนใช้งานจริง!
-- ============================================================
local SECRET_KEY = "CHANGE_ME_TO_RANDOM_64_CHARS_"
    .. "a8f3e9c1b7d2560f4e8a1c9d3b5f7e2a"

-- ============================================================
-- INTERNAL HASH (djb2 + mixing)
-- ============================================================
local function djb2(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 4294967296
    end
    return hash
end

local function toHex(n, len)
    local hex = string.format("%x", n)
    while #hex < len do
        hex = "0" .. hex
    end
    return hex:sub(-len)
end

-- ============================================================
-- PUBLIC: SIGN / VERIFY
-- ============================================================
function CryptoHelper.Sign(payload)
    local combined = SECRET_KEY .. "::" .. tostring(payload)
    local h1 = djb2(combined)
    local h2 = djb2(payload .. SECRET_KEY .. "salt")
    local h3 = djb2(SECRET_KEY .. "::" .. combined)
    return toHex(h1, 8) .. toHex(h2, 8) .. toHex(h3, 8)
end

function CryptoHelper.Verify(payload, signature)
    return CryptoHelper.Sign(payload) == tostring(signature)
end

-- ============================================================
-- PUBLIC: TIMED TOKEN
-- ============================================================
function CryptoHelper.MakeTimedToken(payload, lifetime)
    local expiry = os.time() + (lifetime or 60)
    local msg    = tostring(payload) .. "|" .. expiry
    return msg .. "|" .. CryptoHelper.Sign(msg), expiry
end

function CryptoHelper.VerifyTimedToken(token)
    if typeof(token) ~= "string" then
        return false, "INVALID"
    end

    local parts = {}
    for p in string.gmatch(token, "([^|]+)") do
        table.insert(parts, p)
    end

    if #parts ~= 3 then
        return false, "MALFORMED"
    end

    local payload, expiry, sig = parts[1], tonumber(parts[2]), parts[3]
    if not expiry then
        return false, "BAD_EXPIRY"
    end
    if os.time() > expiry then
        return false, "EXPIRED"
    end
    if not CryptoHelper.Verify(payload .. "|" .. expiry, sig) then
        return false, "BAD_SIGNATURE"
    end

    return true, payload
end

-- ============================================================
-- PUBLIC: LOG CHAIN
-- ============================================================
local logChain = "genesis"

function CryptoHelper.ChainLog(entry)
    logChain = CryptoHelper.Sign(logChain .. "|" .. tostring(entry))
    return logChain
end

function CryptoHelper.GetChain()
    return logChain
end

function CryptoHelper.VerifyChain(expected)
    return logChain == tostring(expected)
end

print("[CRYPTO] Helper loaded")
return CryptoHelper
