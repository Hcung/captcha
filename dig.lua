print('[DIGSITE-V3] Farm Flimsy → Pro → Amethyst (v3.12 = B1 reset Amethyst / A1 diamond idle / B5 craft lock / A2-A5 / B2-B4 / C fixes / FPS 8)')

-- Đợi game + LocalPlayer + Character sẵn sàng TRƯỚC KHI chạy bất cứ thứ gì
-- (autoexec chạy quá sớm thì LocalPlayer = nil -> lỗi "attempt to index nil with 'Character'")
if not game:IsLoaded() then game.Loaded:Wait() end

do
    local Players = game:GetService("Players")
    local t0 = os.clock()
    repeat task.wait(0.25) until Players.LocalPlayer or os.clock() - t0 > 60
    local lp = Players.LocalPlayer
    if lp then
        repeat task.wait(0.25) until lp.Character or os.clock() - t0 > 60
    end
end

-- Bật (true) để in cấu trúc zone 1 lần khi vào (chỉ dùng khi debug). Mặc định tắt cho đỡ rác console
local DEBUG_DUMP_ZONE = false
-- Không tăng coin trong bao nhiêu giây thì coi là stuck
local STUCK_SECONDS = 15
-- Zone Advanced mất/hỏng liên tục bao nhiêu giây thì coi là map reset và rejoin
local ZONE_LOST_SECONDS = 3
-- Rejoin zone thất bại liên tiếp N lần thì vào lại CÙNG server (không hop sang server khác)
local REJOIN_SERVER_AFTER_FAILS = 3
-- Đặt false nếu autoexec của bạn đã tự nạp Anti-AFK (tránh chạy 2 bản, bản nạp quá sớm sẽ báo lỗi 'Character')
local LOAD_ANTI_AFK = true
-- Hop server: mỗi chế độ quét tối đa bao nhiêu page (100 server/page)
local HOP_MAX_PAGES = 1
-- Khi phải chọn server NHIỀU người (fallback): server phải còn ít nhất N slot trống
local HOP_FREE_SLOTS_MOST = 2
-- Sau khi gọi teleport, chờ tối đa bao nhiêu giây; còn ở server cũ = teleport fail -> thử server khác
local HOP_TELEPORT_WAIT = 20
-- Digsite thường: ActiveBlocks rỗng quá N giây thì rejoin zone (block chưa sinh ra)
local BLOCKS_WAIT_TIMEOUT = 25
-- Advanced: không có block đúng màu -> đào block cao nhất để mở đường xuống. 1 block thử quá N lần vẫn còn thì bỏ qua 15s
local DIG_TOP_MAX_TRIES = 3
-- Quét lại toàn bộ ActiveBlocks để cập nhật tập magic block mỗi N giây (ngoài ra cập nhật theo sự kiện ChildAdded/ChildRemoved)
local MAGIC_RESCAN_SECONDS = 2.0
-- Ở tầng đáy (hoặc hết block) liên tục bao nhiêu giây thì mới tele lên TunnelTop
local BOTTOM_STAY_SECONDS = 10
-- ===== TỐC ĐỘ =====
-- Vòng lặp chạy theo frame nên bị khống chế bởi FPS cap (cao = đào nhanh hơn nhưng tốn CPU hơn). Đang đặt 8
local FPS_CAP = 8
-- Mỗi lần đào: gửi lệnh DigBlock cho tối đa N block gần nhau (cùng màu, trong bán kính). 1 = tắt
local DIG_BATCH = 1
-- Số lệnh DigBlock gửi mỗi frame khi đào 1 block (1 = như cũ; thử 2 để nhanh gấp đôi nếu server chịu)
local DIG_FIRES_PER_TICK = 4
local DIG_BATCH_RADIUS = 30
-- Đọc lại inventory/coins tối đa mỗi N giây (trước đây đọc MỖI vòng lặp)
local STATE_UPDATE_INTERVAL = 0.5
-- Cache số Bucket (đọc Save mỗi lần khá tốn): tách riêng khỏi STATE_UPDATE_INTERVAL
local BUCKET_CACHE_SECONDS = 0.2
-- ===== AUTO CRAFT HUGE POTION =====
local AUTO_CRAFT_HUGE_POTION = true
local CRAFT_HUGE_MIN_BUCKET = 16
local CRAFT_HUGE_BATCH_SIZE = 50
local CRAFT_HUGE_CHECK_INTERVAL = 5.0
local lastCraftCheck = 0
-- ===== DIAMOND UPGRADE MODE =====
-- Lilac: tầng 20-40
local DIAMOND_LILAC_MIN_FLOOR = 20
local DIAMOND_LILAC_MAX_FLOOR = 40
-- Smoky grey: tầng 45-50
local DIAMOND_SMOKY_MIN_FLOOR = 45
local DIAMOND_SMOKY_MAX_FLOOR = 50
-- Gặp block chặn (Really black / Royal purple...) liên tiếp N lần ở CÙNG 1 tầng => khu magic block => HOP server (dùng method hop hiện tại)
local DIAMOND_BLOCK_HOP_AFTER = 3
-- [A1] Diamond upgrade: không có block nào để đào quá N giây thì xử lý (đã tới tầng target -> HOP, chưa tới -> rejoin)
local DIAMOND_IDLE_SECONDS = 12   -- phải NHỎ HƠN STUCK_SECONDS (15) thì mới chạy trước checkStuck
-- [A4] Gửi Diamond: tối thiểu N giây giữa 2 lần thử gửi (tránh spam mail + chặn farm)
local DIAMOND_SEND_COOLDOWN = 30
-- [B4] 1 chest bắn DigChest quá N lần vẫn còn -> bỏ qua chest đó CHEST_IGNORE_SECONDS giây (khỏi kẹt + HOP timer chạy được)
local CHEST_MAX_ATTEMPTS = 60
local CHEST_IGNORE_SECONDS = 30
local DIAMOND_TRANSIT_COLORS = {
    ["Medium blue"] = true,
    ["Bright blue"] = true,
}
local DIAMOND_TARGET_COLORS = {
    ["Lilac"] = true,
    ["Smoky grey"] = true,
}
-- Điểm "TunnelTop" của Digsite thường (vị trí trên cùng để tp lên khi hết block bên dưới)
local DIGSITE_TOP_CFRAME = CFrame.new(
    -128.10646057128906, 62.206214904785156, -2525.46875,
    0.489628822, 6.52916441e-08, -0.871930957,
    3.76888956e-08, 1, 9.60456887e-08,
    0.871930957, -7.98888564e-08, 0.489628822
)

-- Anti-AFK
if LOAD_ANTI_AFK then
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://gist.githubusercontent.com/lekama9999/39ef4fd7aea8e24079425e54dc81ed93/raw/73818097b65dfd3e2958cb7ad952acb67efd40ae/antiafk"))()
    end)
end)
end

-- ===== HUGE POTION CRAFT HELPERS =====
local function itemAmount(data)
    return tonumber(data._am or data.am or data.amount or data.Amount or 1) or 1
end

local function eachItem(inv, onItem)
    local seen = {}
    local function scan(classItems, defaultCategory)
        if type(classItems) ~= "table" then return end
        for _, data in pairs(classItems) do
            if type(data) == "table" and data.id ~= nil and not seen[data] then
                seen[data] = true
                onItem(data, defaultCategory)
            end
        end
    end
    for category, catItems in pairs(inv) do
        if category ~= "Currency" and category ~= "_uq" and category ~= "ct" then
            scan(catItems, category)
        end
    end
    if type(inv._uq) == "table" then scan(inv._uq.ct, nil) end
    scan(inv.ct, nil)
end

local function sumItemAmount(inv, targetNames)
    if type(targetNames) == "string" then targetNames = { targetNames } end
    local wanted = {}
    for _, name in ipairs(targetNames) do wanted[tostring(name)] = true end
    local total = 0
    eachItem(inv, function(data)
        if wanted[tostring(data.id)] then total = total + itemAmount(data) end
    end)
    return total
end

local function tryGetInventory()
    local ok, save = pcall(function()
        return require(game:GetService("ReplicatedStorage").Library.Client.Save).Get()
    end)
    if ok then return save.Inventory or nil end
    return nil
end

local function checkBucketMagic()
    local inv = tryGetInventory()
    if not inv then return 0 end
    return sumItemAmount(inv, { "Bucket O' Magic" })
end

-- [B5] Hàm craft thật (đổi tên từ autoCraftHugePotion). Gọi qua wrapper autoCraftHugePotion bên dưới để có lock.
local function doCraftHugePotion()
    if not AUTO_CRAFT_HUGE_POTION then return end

    local now = os.clock()
    if now - lastCraftCheck < CRAFT_HUGE_CHECK_INTERVAL then return end
    lastCraftCheck = now

    local inv = tryGetInventory()
    if not inv then return end

    -- Chưa đủ Bucket O' Magic thì im lặng (không in log mỗi 5s)
    local bucketCount = sumItemAmount(inv, { "Bucket O' Magic" })
    if bucketCount < CRAFT_HUGE_MIN_BUCKET then return end

    local Network = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
    local machine = Network and Network:FindFirstChild("MagicMachine_Activate")
    if not machine then
        print('[DIGSITE-CRAFT] ❌ Không thấy remote MagicMachine_Activate')
        return
    end

    print(string.format("[DIGSITE-CRAFT] Bucket O' Magic = %d (≥ %d) → craft Huge Potion", bucketCount, CRAFT_HUGE_MIN_BUCKET))

    local crafted = 0
    for i = 1, CRAFT_HUGE_BATCH_SIZE do
        local invNow = tryGetInventory()
        -- Dừng khi không còn đủ nguyên liệu (trước đây chỉ dừng khi < 1 nên cứ bắn remote thừa)
        if not invNow or sumItemAmount(invNow, { "Bucket O' Magic" }) < CRAFT_HUGE_MIN_BUCKET then break end

        local before = sumItemAmount(invNow, { "Huge" })
        local ok, err = pcall(function()
            return machine:InvokeServer("Huge Potion")
        end)
        if not ok then
            print('[DIGSITE-CRAFT] ❌ InvokeServer lỗi: ' .. tostring(err))
            break
        end

        -- Chờ inventory cập nhật (tối đa ~3s), phải thấy Huge tăng mới tính là craft thành công
        local success = false
        for _ = 1, 6 do
            task.wait(0.5)
            if sumItemAmount(tryGetInventory() or {}, { "Huge" }) > before then
                success = true
                break
            end
        end

        if success then
            crafted = crafted + 1
        else
            print(string.format('[DIGSITE-CRAFT] Craft #%d không làm Huge tăng → dừng', i))
            break
        end
    end

    print(string.format("[DIGSITE-CRAFT] Xong: craft %d Huge Potion | Bucket O' Magic còn %d",
        crafted, checkBucketMagic()))
end

-- [B5] Wrapper có lock: không cho 2 luồng craft chạy song song; pcall để lỗi giữa chừng không kẹt cờ.
local crafting = false
local function autoCraftHugePotion()
    if crafting then return end
    crafting = true
    local ok, err = pcall(doCraftHugePotion)
    crafting = false
    lastCraftCheck = os.clock()   -- tính cooldown từ lúc craft XONG
    if not ok then
        print('[DIGSITE-CRAFT] ❌ Lỗi: ' .. tostring(err))
    end
end

local function withIdentity(n, fn)
    local ok, result
    pcall(function() setthreadidentity(n) end)
    ok, result = pcall(fn)
    pcall(function() setthreadidentity(2) end)
    return ok, result
end

-- Forward declaration cho các hàm phía dưới
local Farm
local State
local Transition
local boostDigsiteFPS

-- =========== CLAIM + SEND DIAMOND ===========
local DIAMOND_RECEIVER = "keserfpg966"
-- Acc main (người nhận) không tự gửi Diamond cho chính nó được -> bỏ qua toàn bộ bước gửi Diamond
local IS_DIAMOND_RECEIVER = (game:GetService("Players").LocalPlayer.Name:lower() == DIAMOND_RECEIVER:lower())
local SaveModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save"))
local NetworkFolder = game:GetService("ReplicatedStorage"):WaitForChild("Network", 10)
local QR_Dispatch = NetworkFolder and NetworkFolder:WaitForChild("QR_Dispatch", 10)
local ClaimAllRemote = NetworkFolder and NetworkFolder:WaitForChild("Mailbox: Claim All", 10)

local function getInventoryClass(className)
    local playerData = SaveModule.Get()
    local inv = playerData and playerData.Inventory
    if type(inv) ~= "table" then return nil end
    if type(inv[className]) == "table" then return inv[className] end
    if inv._uq and inv._uq.ct and type(inv._uq.ct[className]) == "table" then return inv._uq.ct[className] end
    if inv.ct and type(inv.ct[className]) == "table" then return inv.ct[className] end
    return nil
end

local function findDiamondShovel()
    local playerData = SaveModule.Get()
    local inv = playerData and playerData.Inventory
    if type(inv) ~= "table" then return nil, 0, nil end

    local function scanClass(classData)
        if type(classData) ~= "table" then return nil end
        for uid, data in pairs(classData) do
            if type(data) == "table" then
                local id = data.id or data._id or data.ID
                if id == "Diamond Shovel" then return uid end
            end
        end
        return nil
    end

    for className, classData in pairs(inv) do
        if className ~= "_uq" and className ~= "ct" and className ~= "Currency" then
            local uid = scanClass(classData)
            if uid then return uid, 1, className end
        end
    end

    local roots = {}
    if type(inv._uq) == "table" and type(inv._uq.ct) == "table" then roots[#roots + 1] = inv._uq.ct end
    if type(inv.ct) == "table" then roots[#roots + 1] = inv.ct end
    for _, root in ipairs(roots) do
        for className, classData in pairs(root) do
            local uid = scanClass(classData)
            if uid then return uid, 1, className end
        end
    end
    return nil, 0, nil
end

local function sendMailPayload(recipient, mailType, itemUID, amount)
    if not QR_Dispatch then return false, "QR_Dispatch missing" end
    for attempt = 1, 5 do
        local ok, response = pcall(function()
            return QR_Dispatch:InvokeServer(tostring(recipient), "12", tostring(mailType), itemUID, tonumber(amount))
        end)
        if ok then return true, response end
        warn(("[SEND] InvokeServer fail %d/5: %s"):format(attempt, tostring(response)))
        task.wait(1 + attempt)
    end
    return false, "max retries"
end

local function getMailHistoryList()
    local ok, playerData = pcall(function()
        return SaveModule.Get()
    end)
    if not ok or not playerData then return nil end
    if type(playerData.MailLog) == "table" then return playerData.MailLog end
    return nil
end

local function isInMailHistory(receiverName, sinceTimestamp)
    local history = getMailHistoryList()
    if not history then return nil end
    local target = string.lower(receiverName)
    for _, entry in pairs(history) do
        if type(entry) == "table" then
            local entryName = entry.RecieverName
            local entryType = entry.Type
            if entryName and string.lower(tostring(entryName)) == target and (entryType == nil or entryType == "Sent") then
                if sinceTimestamp then
                    local entryTime = entry.Timestamp or entry.SentTime or entry.Time
                    -- [A4] entry không có timestamp = không xác minh được là mới -> bỏ qua (tránh xác nhận nhầm entry cũ)
                    if type(entryTime) ~= "number" or entryTime < sinceTimestamp then
                        continue
                    end
                end
                return true
            end
        end
    end
    return false
end

-- [A4] Xác nhận gửi xong: (1) Diamond đã biến mất khỏi inventory, hoặc (2) có entry MỚI trong MailLog
local function confirmDiamondSent(sentUid)
    local since = os.time() - 5
    for _ = 1, 8 do
        local ok, stillUid = pcall(findDiamondShovel)
        if ok and stillUid ~= sentUid then return true end
        if isInMailHistory(DIAMOND_RECEIVER, since) then return true end
        task.wait(1)
    end
    return false
end

local function claimAllMail()
    if not ClaimAllRemote then return false end
    local ok, result = pcall(function()
        return ClaimAllRemote:InvokeServer()
    end)
    if ok then
        print("[CLAIM] Claimed mail ✓")
        return true
    end
    warn("[CLAIM] Lỗi: " .. tostring(result))
    return false
end

local lastDiamondSendAttempt = -math.huge
local function sendDiamondToReceiver()
    if IS_DIAMOND_RECEIVER then return false end
    -- [A4] cooldown: không thử gửi liên tục mỗi vòng lặp
    if os.clock() - lastDiamondSendAttempt < DIAMOND_SEND_COOLDOWN then return false end
    lastDiamondSendAttempt = os.clock()

    local uid, amount, className = findDiamondShovel()
    if not uid then
        warn('[DIGSITE] Diamond Shovel not found in inventory')
        return false
    end

    print(('[DIGSITE] Found Diamond Shovel | UID=%s | Class=%s | Sending to %s...'):format(tostring(uid), tostring(className), DIAMOND_RECEIVER))
    local ok, response = sendMailPayload(DIAMOND_RECEIVER, className or "Misc", uid, amount)

    if not ok then
        warn(('[DIGSITE] ❌ Send Diamond failed: %s'):format(tostring(response)))
        return false
    end

    print('[DIGSITE] Diamond mail sent, waiting for confirmation...')
    if confirmDiamondSent(uid) then
        print('[DIGSITE] ✓ Diamond send confirmed')
        task.wait(2)
        return true
    else
        warn(('[DIGSITE] ⚠️ Diamond send unconfirmed, thử lại sau %ds'):format(DIAMOND_SEND_COOLDOWN))
        return false
    end
end

-- Super Magnet (giống script Bucket O' Magic). Trước đây 2 biến này không tồn tại (nil) nên patch không có tác dụng.
-- Đặt SUPER_MAGNET_ENABLED = false nếu muốn tắt hẳn.
local SUPER_MAGNET_ENABLED = true
local MAGNET_POWER = 100000

local MagnetRestore = {}


local function safeClientModule(name)
    local LibraryRoot = game:GetService("ReplicatedStorage"):WaitForChild("Library")
    local moduleScript = LibraryRoot.Client:FindFirstChild(name)
    if not moduleScript then
        moduleScript = LibraryRoot.Client:WaitForChild(name, 10)
    end
    if not moduleScript then
        print('[DIGSITE] Super Magnet module missing:', name)
        return nil
    end
    local ok, res = pcall(require, moduleScript)
    if not ok then
        print('[DIGSITE] require failed', name, res)
        return nil
    end
    return res
end

local function patchMagnetPower(moduleName, matcher)
    local module = safeClientModule(moduleName)
    if not module then
        print('[DIGSITE] Super Magnet module not found:', moduleName)
        return false
    end
    if type(module) ~= "table" then
        print('[DIGSITE] Super Magnet module not table:', moduleName)
        return false
    end
    if type(module.GetPower) ~= "function" then
        print('[DIGSITE] Super Magnet unavailable:', moduleName .. '.GetPower')
        return false
    end

    local original = module.GetPower
    local wrapper = function(...)
        local powerName = ...
        if SUPER_MAGNET_ENABLED and matcher(powerName) then
            return MAGNET_POWER
        end
        return original(...)
    end

    local ok, err = pcall(function()
        if type(setreadonly) == "function" then
            pcall(setreadonly, module, false)
        end
        module.GetPower = wrapper
        if type(setreadonly) == "function" then
            pcall(setreadonly, module, true)
        end
    end)

    if not ok then
        print('[DIGSITE] Super Magnet patch failed:', moduleName, tostring(err))
        return false
    end

    MagnetRestore[#MagnetRestore + 1] = function()
        pcall(function()
            if type(setreadonly) == "function" then
                pcall(setreadonly, module, false)
            end
            if module.GetPower == wrapper then
                module.GetPower = original
            end
        end)
    end

    print('[DIGSITE] Super Magnet patched:', moduleName)
    return true
end

local function applyMagnetConfig(result)
    if type(result) ~= "table" then return end
    if type(result.config) ~= "table" then
        result.config = {}
    end
    local config = result.config
    config.SuperMagnet = true
end

local function patchInstancingMagnet()
    local module = safeClientModule("InstancingCmds")
    if not module then
        print('[DIGSITE] Super Magnet module not found: InstancingCmds')
        return false
    end
    if type(module) ~= "table" then
        print('[DIGSITE] Super Magnet module not table: InstancingCmds')
        return false
    end
    if type(module.Get) ~= "function" then
        print('[DIGSITE] Super Magnet unavailable: InstancingCmds.Get')
        return false
    end

    local original = module.Get
    local wrapper = function(...)
        local results = table.pack(original(...))
        if SUPER_MAGNET_ENABLED and type(results[1]) == "table" then
            pcall(applyMagnetConfig, results[1])
        end
        return table.unpack(results, 1, results.n)
    end

    local ok, err = pcall(function()
        if type(setreadonly) == "function" then
            pcall(setreadonly, module, false)
        end
        module.Get = wrapper
        if type(setreadonly) == "function" then
            pcall(setreadonly, module, true)
        end
    end)

    if not ok then
        print('[DIGSITE] Super Magnet patch failed: InstancingCmds.Get', tostring(err))
        return false
    end

    MagnetRestore[#MagnetRestore + 1] = function()
        pcall(function()
            if type(setreadonly) == "function" then
                pcall(setreadonly, module, false)
            end
            if module.Get == wrapper then
                module.Get = original
            end
        end)
    end

    print('[DIGSITE] Super Magnet patched: InstancingCmds')
    return true
end

local magnetEnchantOK = patchMagnetPower("EnchantCmds", function(name)
    return name == "Super Magnet" or name == "Magnet"
end)

local magnetUpgradeOK = patchMagnetPower("UpgradeCmds", function(name)
    return name == "Magnet"
end)

local magnetInstancingOK = patchInstancingMagnet()
print(string.format(
    '[DIGSITE] Super Magnet hooks: Enchant=%s Upgrade=%s Instancing=%s',
    tostring(magnetEnchantOK), tostring(magnetUpgradeOK), tostring(magnetInstancingOK)
))


-- =========== ZONE RESOLUTION ===========
local function resolveActiveZone()
    local ok, active = pcall(function()
        return game:GetService("Workspace").__THINGS.__INSTANCE_CONTAINER.Active
    end)
    if not ok or not active then return nil end

    if active:FindFirstChild("AdvancedDigsite") then
        return "AdvancedDigsite"
    elseif active:FindFirstChild("Digsite") then
        return "Digsite"
    end
    return nil
end

local function getZoneObject(zoneName)
    local ok, active = pcall(function()
        return game:GetService("Workspace").__THINGS.__INSTANCE_CONTAINER.Active
    end)
    if not ok or not active then return nil end
    return active:FindFirstChild(zoneName)
end

local function waitForZoneReady(zoneName, timeout, needBlocks)
    timeout = timeout or 30
    local start = os.clock()
    repeat
        local zone = getZoneObject(zoneName)
        if zone and zone:FindFirstChild("Important") then
            local imp = zone.Important
            local blocks = imp:FindFirstChild("ActiveBlocks")
            local chests = imp:FindFirstChild("ActiveChests")
            local spawns = imp:FindFirstChild("Spawns")
            local tunnelTop = imp:FindFirstChild("TunnelTop")

            if blocks and chests and spawns and tunnelTop then
                if not needBlocks or #blocks:GetChildren() > 0 then
                    return true
                end
            end
        end
        task.wait(0.25)
    until os.clock() - start > timeout
    return false
end

-- [FIX] Farm phải chạy theo zone hiện tại (trước đây hard-code AdvancedDigsite nên ở Digsite thường không làm gì)
local function farmZoneName()
    return (State and State.zonePhase == "ADVANCED") and "AdvancedDigsite" or "Digsite"
end

local dumpedZones = {}
local function dumpZone(zoneName)
    if not DEBUG_DUMP_ZONE or dumpedZones[zoneName] then return end
    local zone = getZoneObject(zoneName)
    if not zone then
        print('[DIGSITE][DUMP] zone not found: ' .. zoneName)
        return
    end
    dumpedZones[zoneName] = true
    print('[DIGSITE][DUMP] ' .. zoneName .. ' children:')
    for _, c in ipairs(zone:GetChildren()) do
        print('   - ' .. c.Name .. ' (' .. c.ClassName .. ')')
    end
    local imp = zone:FindFirstChild("Important")
    if imp then
        print('[DIGSITE][DUMP] ' .. zoneName .. '.Important children:')
        for _, c in ipairs(imp:GetChildren()) do
            print('   - ' .. c.Name .. ' (' .. c.ClassName .. ', ' .. #c:GetChildren() .. ' children)')
        end
    end
end

local function diagnosticAdvancedBlocks(zoneName)
    local zone = getZoneObject(zoneName)
    if not zone or not zone:FindFirstChild("Important") then return end
    local activeBlocks = zone.Important:FindFirstChild("ActiveBlocks")
    if not activeBlocks then return end

    local blocks = activeBlocks:GetChildren()
    local classes, colors, withCoord = {}, {}, 0
    local minY, maxY = math.huge, -math.huge

    for _, b in ipairs(blocks) do
        classes[b.ClassName] = (classes[b.ClassName] or 0) + 1
        if b:IsA("BasePart") then
            local n = b.BrickColor.Name
            colors[n] = (colors[n] or 0) + 1
            minY = math.min(minY, b.Position.Y)
            maxY = math.max(maxY, b.Position.Y)
        end
        if b:GetAttribute('Coord') then withCoord = withCoord + 1 end
    end

    local function fmt(t)
        local out = {}
        for k, v in pairs(t) do out[#out + 1] = k .. "=" .. v end
        table.sort(out)
        return table.concat(out, ", ")
    end
    print(string.format('[DIGSITE][DIAG] %s ActiveBlocks: Total=%d | WithCoord=%d | Classes{%s} | Colors{%s} | BlockY=%.1f..%.1f',
        zoneName, #blocks, withCoord, fmt(classes), fmt(colors), minY, maxY))
end

-- =========== INSTANCING ===========
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Instancing = require(RS:WaitForChild("Library"):WaitForChild("Client"):WaitForChild("InstancingCmds"))

-- Zone có đủ cấu trúc chưa (model còn nhưng thiếu Important = zone đang hỏng / đang bị reset)
local function inspectZoneStructure(zoneName)
    local zone = getZoneObject(zoneName)

    if not zone then
        return false, "zone_missing"
    end

    local important = zone:FindFirstChild("Important")

    if not important then
        return false, "Important_missing"
    end

    local required = {
        "ActiveBlocks",
        "ActiveChests",
        "TunnelTop",
    }

    for _, name in ipairs(required) do
        if not important:FindFirstChild(name) then
            return false, name .. "_missing"
        end
    end

    return true, "ok"
end

local function zoneHasImportant(zoneName)
    local valid = inspectZoneStructure(zoneName)
    return valid
end

local function inInstanceNow()
    local ok, v = pcall(function() return Instancing.IsInInstance() end)
    return (ok and v) and true or false
end

local function isMainWorld()
    return not inInstanceNow() and resolveActiveZone() == nil
end

-- Thoát HẲN instance hiện tại (kể cả khi zone đã hỏng/biến mất) rồi chờ game cập nhật trạng thái.
-- Trước đây chỉ Exit khi zone còn nguyên -> zone hỏng thì bỏ qua Exit, Enter bị từ chối và client kẹt trong instance cũ.
local function leaveInstance(zoneName)
    -- Thoát hẳn instance về Main World
    -- Phương pháp: LeaveViaExit() đã được verify thành công

    if isMainWorld() then
        return true
    end

    if inInstanceNow() then
        pcall(function() Instancing.LeaveViaExit() end)
    end

    local started = os.clock()
    repeat
        task.wait(0.25)
    until isMainWorld() or os.clock() - started > 12

    if isMainWorld() then
        return true
    end

    return false
end

local function isInAdvancedDigsite()
    if not inInstanceNow() then return false end
    return resolveActiveZone() == "AdvancedDigsite" and zoneHasImportant("AdvancedDigsite")
end

local function joinAdvancedDigsite()
    if isInAdvancedDigsite() then
        return true
    end

    -- Phải thoát hẳn về Main World trước khi Enter
    if not leaveInstance("AdvancedDigsite") then
        print('[DIGSITE] ❌ Cannot leave current instance')
        return false
    end

    print('[DIGSITE] Entering AdvancedDigsite...')
    local ok, err = pcall(function()
        Instancing.Enter("AdvancedDigsite")
    end)

    if not ok then
        print('[DIGSITE] Enter failed: ' .. tostring(err))
        return false
    end

    local start = tick()
    while tick() - start < 30 do
        if isInAdvancedDigsite() then
            print('[DIGSITE] ✓ Entered AdvancedDigsite')
            return true
        end
        task.wait(0.5)
    end

    print('[DIGSITE] Enter timeout, active: ' .. tostring(resolveActiveZone()))
    return false
end

-- =========== STATE ===========
State = {
    zonePhase = "DIGSITE",  -- DIGSITE | ADVANCED
    coins = 0,
    shovel = "Flimsy Shovel",
    lastLog = os.clock(),
    stuckCheckTime = os.clock(),
    stuckLastCoins = 0,
    stuckLastBlockCount = 0,
    stuckLastChestCount = 0,
    farmState = "IDLE",
    digsiteBoosted = false,
    rejoinAdvancedFails = 0,
}

local SHOVELS = {
    DIGSITE = {
        {name = "Flimsy Shovel", price = 0},
        {name = "Normal Shovel", price = 2000},
        {name = "Bluesteel Shovel", price = 12500},
        {name = "Sharp Shovel", price = 55000},
        {name = "Pro Shovel", price = 250000},
    },
    ADVANCED = {
        {name = "Platinum Shovel", price = 250000},
        {name = "Emerald Shovel", price = 1250000},
        {name = "Sapphire Shovel", price = 4000000},
        {name = "Amethyst Shovel", price = 12500000},
    }
}

local SHOVEL_ORDER = {"Diamond Shovel", "Amethyst Shovel", "Sapphire Shovel", "Emerald Shovel", "Platinum Shovel", "Pro Shovel", "Sharp Shovel", "Bluesteel Shovel", "Normal Shovel", "Flimsy Shovel"}

local function shovelRank(name)
    for i, n in ipairs(SHOVEL_ORDER) do
        if n == name then return i end
    end
    return 99
end

local function shovelPrice(name)
    for _, list in pairs(SHOVELS) do
        for _, s in ipairs(list) do
            if s.name == name then return s.price end
        end
    end
    return 0
end

local function normName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end

State.confirmed = {}
State.lastShovelDump = ""

function State:ownsShovel(name)
    return (self.ownedShovels and self.ownedShovels[normName(name)] == true) or self.confirmed[name] == true
end

function State:detectShovel(save, force)
    if not force and self.shovelScanned and os.clock() - (self.lastShovelScan or 0) < 3 then
        return self.shovelCache
    end
    self.shovelScanned = true
    self.lastShovelScan = os.clock()

    local inv = save and save.Inventory
    if type(inv) ~= "table" then return nil end

    local owned, dump = {}, {}
    local function check(catName, item)
        if type(item) == "table" and type(item.id) == "string" and item.id:lower():find("shovel", 1, true) then
            owned[normName(item.id)] = true
            dump[#dump + 1] = tostring(catName) .. ":" .. item.id
            return true
        end
        return false
    end
    local function scanClass(catName, cat)
        if type(cat) ~= "table" then return end
        for _, item in pairs(cat) do
            if type(item) == "table" and not check(catName, item) and item.id == nil then
                for _, it2 in pairs(item) do check(catName, it2) end   -- dạng lồng thêm 1 tầng
            end
        end
    end
    -- [A5] quét inventory thường + _uq.ct + ct
    for catName, cat in pairs(inv) do
        if catName ~= "_uq" and catName ~= "ct" then scanClass(catName, cat) end
    end
    if type(inv._uq) == "table" and type(inv._uq.ct) == "table" then
        for catName, cat in pairs(inv._uq.ct) do scanClass("uq." .. tostring(catName), cat) end
    end
    if type(inv.ct) == "table" then
        for catName, cat in pairs(inv.ct) do scanClass("ct." .. tostring(catName), cat) end
    end

    self.ownedShovels = owned
    table.sort(dump)
    local dumpStr = table.concat(dump, ", ")
    if dumpStr ~= self.lastShovelDump then
        self.lastShovelDump = dumpStr
        print('[DIGSITE] Inventory shovels: ' .. (dumpStr ~= "" and dumpStr or "(none)"))
    end

    -- [A3] Đã có Amethyst thì shovel hiện tại = Amethyst dù Diamond chưa gửi đi (để chạy đúng logic farm Amethyst)
    local hasAmethyst = owned[normName("Amethyst Shovel")] or self.confirmed["Amethyst Shovel"]
    for _, name in ipairs(SHOVEL_ORDER) do
        if not (name == "Diamond Shovel" and hasAmethyst) and (owned[normName(name)] or self.confirmed[name]) then
            self.shovelCache = name
            return name
        end
    end
    self.shovelCache = nil
    return nil
end

function State:update(force)
    if not force and os.clock() - (self.lastUpdate or 0) < STATE_UPDATE_INTERVAL then return end
    self.lastUpdate = os.clock()
    local ok, save = withIdentity(2, function()
        return require(game:GetService("ReplicatedStorage").Library.Client.Save).Get()
    end)
    if not ok or not save then return end

    if save.Inventory and save.Inventory.Currency then
        for _, item in pairs(save.Inventory.Currency) do
            if item.id == "Digsite" then
                self.coins = item._am or 0
                break
            end
        end
    end

    if save.Inventory then
        local best = self:detectShovel(save, force)
        if best then
            -- [B1] Đổi sang Amethyst (gửi Diamond xong / mua Amethyst xong) -> reset timer farm
            local prev = self.shovel
            self.shovel = best
            if best == "Amethyst Shovel" and prev ~= "Amethyst Shovel"
                and Farm and Farm.resetForAmethyst then
                Farm:resetForAmethyst()
            end
        end
    end
end

function State:log()
    if os.clock() - self.lastLog < 5 then return end

    if self.zonePhase == "ADVANCED"
        and self.shovel == "Amethyst Shovel"
        and Farm
        and Farm.phase then
        local bucket = self:getBucketCount()
        local ok, chestCount = pcall(function() return Farm:countChests() end)
        chestCount = ok and chestCount or 0
        local ok2, magicCount = pcall(function() return Farm:countMagicBlocks() end)
        magicCount = ok2 and magicCount or 0

        print(string.format('[DIGSITE] FARM | Zone: %s | Phase: %s | Bucket: %d | Chests: %d | Magic: %d',
            self.zonePhase, Farm.phase, bucket, chestCount, magicCount))
    else
        local next = self:getNextShovel()
        local nextStr = next and next.name or "DONE"
        local okb, nb = pcall(function() return Farm:countBlocks() end)
        local okc, nc = pcall(function() return Farm:countChests() end)
        print(string.format('[DIGSITE] %s | Coins: %d | Shovel: %s | Next: %s | Blocks: %d | Chests: %d',
            self.zonePhase, self.coins, self.shovel, nextStr, okb and nb or -1, okc and nc or -1))
    end

    self.lastLog = os.clock()
end

function State:getBucketCount()
    if self.bucketCache and os.clock() - (self.bucketAt or 0) < BUCKET_CACHE_SECONDS then
        return self.bucketCache
    end
    local ok, count = withIdentity(2, function()
        local save = require(game:GetService("ReplicatedStorage").Library.Client.Save).Get()
        -- Đếm mọi category (test thực tế: acc có Bucket=1 nhưng Misc=0 -> bản chỉ đọc Misc luôn trả 0 -> refill/HOP oan)
        if save.Inventory then
            return sumItemAmount(save.Inventory, { "Bucket" })
        end
        return 0
    end)
    local result = ok and (count or 0) or 0
    self.bucketCache, self.bucketAt = result, os.clock()
    return result
end

-- [FIX] Tìm shovel kế tiếp theo TÊN shovel (không phụ thuộc zone) -> không còn "Next: DONE" sai
function State:getNextShovel()
    local s = self.shovel
    if s == "Pro Shovel" then
        if self.zonePhase == "ADVANCED" then
            for _, shovelName in ipairs({"Platinum Shovel", "Emerald Shovel", "Sapphire Shovel", "Amethyst Shovel"}) do
                if not self:ownsShovel(shovelName) then
                    for _, list in pairs(SHOVELS) do
                        for _, v in ipairs(list) do
                            if v.name == shovelName then return v end
                        end
                    end
                end
            end
            return nil
        else
            return SHOVELS.DIGSITE[1]
        end
    end
    -- Diamond ở Digsite thường: Flimsy được claim bằng ClaimShovel (claimFlimsyShovel), không mua ở merchant
    if s == "Diamond Shovel" and self.zonePhase == "DIGSITE" then
        return nil
    end
    if s == "Diamond Shovel" and self.zonePhase == "ADVANCED" then
        for _, shovelName in ipairs({"Platinum Shovel", "Emerald Shovel", "Sapphire Shovel", "Amethyst Shovel"}) do
            if not self:ownsShovel(shovelName) then
                for _, list in pairs(SHOVELS) do
                    for _, v in ipairs(list) do
                        if v.name == shovelName then return v end
                    end
                end
            end
        end
        return nil
    end
    for _, list in pairs(SHOVELS) do
        for i, v in ipairs(list) do
            if v.name == s then
                return list[i + 1]
            end
        end
    end
    return nil
end

-- [FIX] Reset mốc stuck (gọi sau mỗi lần đổi zone / rejoin)
function State:resetStuck()
    self.stuckCheckTime = os.clock()
    self.stuckLastCoins = self.coins
    local ok, blockCount = pcall(function() return Farm:countBlocks() end)
    local ok2, chestCount = pcall(function() return Farm:countChests() end)
    self.stuckLastBlockCount = ok and blockCount or 0
    self.stuckLastChestCount = ok2 and chestCount or 0
end

-- [FIX] Luôn reset timer sau mỗi lần kiểm tra (trước đây kẹt ở trạng thái stuck vĩnh viễn -> rejoin liên tục)
function State:checkStuck()
    local now = os.clock()
    if now - self.stuckCheckTime < STUCK_SECONDS then return false end

    local okB, blockCount = pcall(function() return Farm:countBlocks() end)
    local okC, chestCount = pcall(function() return Farm:countChests() end)
    blockCount = okB and blockCount or 0
    chestCount = okC and chestCount or 0

    local progress = (self.coins > self.stuckLastCoins) or (blockCount < self.stuckLastBlockCount) or (chestCount < self.stuckLastChestCount)

    if progress then
        self.stuckCheckTime = now
        self.stuckLastCoins = self.coins
        self.stuckLastBlockCount = blockCount
        self.stuckLastChestCount = chestCount
        return false
    end

    self.stuckCheckTime = now
    self.stuckLastCoins = self.coins
    self.stuckLastBlockCount = blockCount
    self.stuckLastChestCount = chestCount

    print(string.format('[DIGSITE] ⚠️ Stuck (no progress in %ds) | Coins: %d | Blocks: %d | Chests: %d', STUCK_SECONDS, self.coins, blockCount, chestCount))
    return true
end

-- =========== FARM ===========
local fireRemote = nil
local function getFireRemote()
    if not fireRemote or not fireRemote.Parent then
        fireRemote = game:GetService("ReplicatedStorage"):WaitForChild("Network"):WaitForChild("Instancing_FireCustomFromClient")
    end
    return fireRemote
end

local BEDROCK_COLOR = BrickColor.new("Really black")
local MAGIC_COLOR = BrickColor.new("Royal purple")   -- tạo 1 lần, không tạo lại cho từng block

local function getRootPart()
    local char = game.Players.LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function blockPos(b)
    if b:IsA("BasePart") then return b.Position end
    if b:IsA("Model") then return b:GetPivot().Position end
    return nil
end

Farm = {
    phase = "CHEST",
    lastChestTime = os.clock(),
    chestTimeout = 60,
    poolTimeout = 200,
    lastPoolSeenAt = nil,
    lastPoolCheck = 0,
    foundSparkles = false,
    lastBucketCount = 0,
    lastChestCount = 0,
    lastMagicCount = 0,
    currentLevel = 1,
    lastBlockCheckTime = os.clock(),
    blockCheckTimeout = 20,
    lastBucketCheckTime = os.clock(),
    bucketCheckInterval = 10,
    refillUsed = false,
    refillStartedAt = nil,
    afterRefill = false,
    lastPeriodicCheck = 0,
    magicToChestCount = 0,
    chestWaitStart = nil,
    chestRetryTimeout = 80,
    lastTopTp = 0,
    chestAttempts = setmetatable({}, {__mode = "k"}),
    chestIgnoreUntil = setmetatable({}, {__mode = "k"}),
    digAttempts = setmetatable({}, {__mode = "k"}),
    digIgnoreUntil = setmetatable({}, {__mode = "k"}),
    lastTopDigLog = 0,
    diamondShaftX = nil,
    diamondShaftZ = nil,
    diamondBadColumns = {},   -- [NEW] cột "X:Z" gặp Really black -> bỏ qua khi chọn shaft
    diamondBlockedFloor = nil,
    diamondBlockedCount = 0,
    diamondPathReached = false,
    diamondIdleSince = nil,   -- [A1] mốc bắt đầu "không có block để đào" trong Diamond upgrade
    lastDiamondPathLog = 0,
    lastDiamondTargetLog = 0,
    stay = {},
    conns = {},
    magicSet = {},
    blockCount = 0,
    boundBlocks = nil,
    lastRescan = 0,
}

-- [B1] Reset toàn bộ timer/cờ khi chuyển sang farm Amethyst (tránh HOP oan do timer cũ từ lúc farm Diamond)
function Farm:resetForAmethyst()
    if self.phase == "HOP" then return end
    local now = os.clock()
    self.phase = "CHEST"
    self.lastChestTime = now
    self.lastPoolSeenAt = now
    self.lastPoolCheck = 0
    self.lastPeriodicCheck = now
    self.lastPoolTopTp = 0
    self.chestWaitStart = nil
    self.magicToChestCount = 0
    self.refillUsed = false
    self.afterRefill = false
    self.refillStartedAt = nil
    self.foundSparkles = false
    self.stay = {}
    self.diamondShaftX, self.diamondShaftZ = nil, nil
    self.diamondBadColumns = {}
    self.diamondBlockedFloor, self.diamondBlockedCount = nil, 0
    self.diamondPathReached = false
    self.diamondIdleSince = nil
    -- xóa danh sách chest/block bị bỏ qua + cache từ phase Diamond (map giữ nguyên nhưng điều kiện đào đã khác)
    self.chestAttempts = setmetatable({}, {__mode = "k"})
    self.chestIgnoreUntil = setmetatable({}, {__mode = "k"})
    self.digAttempts = setmetatable({}, {__mode = "k"})
    self.digIgnoreUntil = setmetatable({}, {__mode = "k"})
    self._bottomAt = nil
    self.noBlocksSince = nil
    -- đang đứng sâu trong hầm của phase Diamond -> về TunnelTop (thực hiện trong Farm:run khi zone đã sẵn sàng)
    self.pendingTopTp = true
    print('[DIGSITE] ✓ Chuyển sang Amethyst → reset timer/phase farm')
end

-- Theo dõi ActiveBlocks bằng sự kiện: lưu sẵn tập magic block + số block, khỏi quét lại mỗi tick.
-- Có quét lại toàn bộ mỗi MAGIC_RESCAN_SECONDS để bắt trường hợp "sparkles"/màu được gán sau khi block xuất hiện.
function Farm:bindZone()
    local zone = getZoneObject(farmZoneName())
    local imp = zone and zone:FindFirstChild("Important")
    local blocks = imp and imp:FindFirstChild("ActiveBlocks")
    if blocks == self.boundBlocks then return blocks ~= nil end

    for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
    self.conns = {}
    self.boundBlocks = blocks
    self.magicSet = {}
    self.blockCount = 0
    if not blocks then return false end

    self.conns[1] = blocks.ChildAdded:Connect(function(v)
        self.blockCount = self.blockCount + 1
        if v:IsA("BasePart") and (v.BrickColor == MAGIC_COLOR or v:FindFirstChild("sparkles")) then
            self.magicSet[v] = true
        end
    end)
    self.conns[2] = blocks.ChildRemoved:Connect(function(v)
        self.blockCount = math.max(0, self.blockCount - 1)
        self.magicSet[v] = nil
    end)
    self:rescanMagic()
    return true
end

function Farm:rescanMagic()
    local blocks = self.boundBlocks
    if not blocks then return end
    local set, n = {}, 0
    for _, v in ipairs(blocks:GetChildren()) do
        n = n + 1
        if v:IsA("BasePart") and (v.BrickColor == MAGIC_COLOR or v:FindFirstChild("sparkles")) then
            set[v] = true
        end
    end
    self.magicSet, self.blockCount = set, n
    self.lastRescan = os.clock()
end

function Farm:hasMagicPool()
    if not self:bindZone() then return nil end
    return next(self.magicSet) ~= nil
end

function Farm:checkEvery20s()
    local now = os.clock()
    if now - self.lastPeriodicCheck < 20 then return end
    self.lastPeriodicCheck = now

    if State.shovel ~= "Amethyst Shovel" then return end

    local bucket = State:getBucketCount()
    local poolExists = self:hasMagicPool()
    local chests = self:countChests()

    self:logEvent(string.format(
        "20s Check | Phase=%s | Bucket=%d | Pool=%s | Chests=%d",
        tostring(self.phase),
        bucket,
        poolExists == true and "YES" or poolExists == false and "NO" or "UNKNOWN",
        chests
    ))

    if self.phase == "MAGIC" and self.afterRefill then
        if bucket <= 0 then
            self.phase = "HOP"
            self:logEvent("20s Check: Bucket empty after refill → HOP")
        elseif poolExists == false then
            self.phase = "HOP"
            self:logEvent("20s Check: Magic Pool depleted → HOP")
        end
    end
end

function Farm:beginRefill()
    if self.refillUsed then
        self.phase = "HOP"
        self:logEvent("Bucket empty after refill → HOP")
        return
    end

    self.refillUsed = true
    self.currentLevel = 1
    self.foundSparkles = false

    -- [B2] dùng TunnelTop thật của instance thay vì CFrame hard-code
    self.lastTopTp = 0
    self:tpTop("refill")

    self.refillStartedAt = os.clock()
    self.phase = "REFILL"
    self:logEvent("Bucket empty first time → TP TunnelTop | Level=1 | REFILL 180s")
end

function Farm:countChests()
    local zone = getZoneObject(farmZoneName())
    if not zone then return 0 end
    local ok, result = pcall(function()
        return zone.Important.ActiveChests:GetChildren()
    end)
    return ok and #result or 0
end

function Farm:countBlocks()
    if not self:bindZone() then return 0 end
    return self.blockCount
end

function Farm:countMagicBlocks()
    if not self:bindZone() then return 0 end
    local n = 0
    for b in pairs(self.magicSet) do
        if b.Parent then n = n + 1 end
    end
    return n
end

function Farm:getTunnelTop()
    local zone = getZoneObject(farmZoneName())
    if not zone then return nil end
    return zone.Important and zone.Important:FindFirstChild("TunnelTop")
end

function Farm:findChest()
    local zone = getZoneObject(farmZoneName())
    if not zone then return nil end

    local ok, chests = pcall(function()
        return zone.Important.ActiveChests:GetChildren()
    end)
    if not ok or #chests == 0 then return nil end

    local rootPart = getRootPart()
    if not rootPart then return nil end
    local playerPos = rootPart.Position
    local closest = nil
    local minDist = 9999

    for _, chest in ipairs(chests) do
        if chest:IsA("Model") and chest:FindFirstChild("Top") and (self.chestIgnoreUntil[chest] or 0) <= os.clock() then
            local dist = (playerPos - chest.Top.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = chest
            end
        end
    end
    return closest
end

function Farm:getPatternFarm()
    if self._pattern then return self._pattern end
    -- khóa số (x * 100 + z) thay cho tostring(Vector3): nhanh hơn rất nhiều khi tra mỗi block
    local P = {}
    local function add(x, z) P[x * 100 + z] = true end
    local Zone = 16

    add(2, 2)

    local n1 = 4
    while n1 < 16 do
        local x, z = n1 - 2, 2
        while x < Zone and z < Zone do
            add(x, z)
            x, z = x + 1, z + 1
        end
        add(n1, 3)
        n1 = n1 + 3
    end
    add(Zone - 1, 2)

    local n2 = 4
    while n2 < 16 do
        local x, z = 2, n2 - 2
        while x < Zone and z < Zone do
            add(x, z)
            x, z = x + 1, z + 1
        end
        add(3, n2)
        n2 = n2 + 3
    end
    add(2, Zone - 1)

    self._pattern = P
    return P
end

function Farm:findMagicBlock()
    if not self:bindZone() then return nil end
    local char = game.Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    -- chỉ duyệt tập magic đã lưu sẵn (rất nhỏ), không quét cả ActiveBlocks
    local pos = root.Position
    local closest, minDist = nil, math.huge
    for b in pairs(self.magicSet) do
        if b.Parent then
            if pos.Y > b.Position.Y and b.BrickColor.Name ~= "Smoky grey" then
                local d = (pos - b.Position).Magnitude
                if d < minDist then closest, minDist = b, d end
            end
        else
            self.magicSet[b] = nil
        end
    end
    return closest
end

function Farm:findBlock()
    local zone = getZoneObject(farmZoneName())
    if not zone then return nil end

    local ok, blocks = pcall(function()
        return zone.Important.ActiveBlocks:GetChildren()
    end)
    if not ok or #blocks == 0 then
        if os.clock() - (self.lastFindBlockLog or 0) >= 10 then
            self.lastFindBlockLog = os.clock()
            print(string.format('[DIGSITE][FINDBLOCK] ActiveBlocks error or empty: ok=%s blocks=%d', tostring(ok), ok and #blocks or 0))
        end
        return nil
    end

    local rootPart = getRootPart()
    if not rootPart then return nil end
    local playerPos = rootPart.Position

    -- Digsite thường: ưu tiên block đúng MÀU của shovel, chưa lộ ra thì đào lớp trên (không theo pattern)
    if State.zonePhase == "DIGSITE" then
        local b = self:findAnyBlock(blocks, playerPos)
        if not b then self:diagBlocks(blocks, playerPos) end
        return b
    end

    -- DIAMOND UPGRADE: xử lý riêng, không được rơi xuống Full Clear thông thường
    if self:isDiamondUpgradePhase() then
        -- GIAI ĐOẠN 1: đào thẳng xuống tầng 45-50
        if not self.diamondPathReached then
            local pathBlock, allowTransit = self:findDiamondDepthPath(blocks)

            if pathBlock then
                return pathBlock, allowTransit
            end

            -- Không tìm được block trong shaft thì chờ
            return nil
        end

        -- GIAI ĐOẠN 2: chỉ farm Lilac và Smoky grey
        local best, bestDistance = nil, math.huge

        for _, block in ipairs(blocks) do
            if block:IsA("BasePart") then
                local coord = block:GetAttribute("Coord")

                if coord then
                    local floor = math.floor(coord.Y + 0.5)

                    if self:isDiamondTargetBlock(block, floor) then
                        local distance = (playerPos - block.Position).Magnitude

                        if distance < bestDistance then
                            best = block
                            bestDistance = distance
                        end
                    end
                end
            end
        end

        if best then
            if os.clock() - self.lastDiamondTargetLog >= 5 then
                self.lastDiamondTargetLog = os.clock()

                print(string.format(
                    '[DIGSITE] DIAMOND TARGET FARM | Color=%s | Coord=%s',
                    best.BrickColor.Name,
                    tostring(best:GetAttribute("Coord"))
                ))
            end

            return best, false
        end

        return nil
    end

    -- Diamond Full Clear (non-upgrade): đào ALL block không filter màu
    if self:isDiamondFullClear() then
        local best, bestD = nil, math.huge
        for _, block in ipairs(blocks) do
            if block:IsA("BasePart") and block:GetAttribute('Coord') then
                local d = (playerPos - block.Position).Magnitude
                if d < bestD then best, bestD = block, d end
            end
        end

        if best then
            if not self.lastDiamondLogTime or os.clock() - self.lastDiamondLogTime >= 5 then
                print(string.format('[DIGSITE] DIAMOND FULL CLEAR | Remaining: %d', #blocks))
                self.lastDiamondLogTime = os.clock()
            end
            return best, false
        end

        return nil
    end

    -- Advanced: 1 lượt duyệt duy nhất (trước đây 2 lượt + tạo closure + tostring(Vector3) cho từng block)
    local pattern = self:getPatternFarm()
    local shovel = State.shovel
    local amethyst = (shovel == "Amethyst Shovel")
    local mediumOnly = (shovel == "Pro Shovel" or shovel == "Platinum Shovel")
    local skipSmoky = self:blockFirstShovel()
    -- [FIX] Ngoài phase MAGIC (CHEST/REFILL) tuyệt đối không đào magic block: mỗi magic block ăn 1 Bucket
    local skipMagic = amethyst and self.phase ~= "MAGIC"
    local py = playerPos.Y

    -- [NEW] Amethyst: chọn block giống nearestBlock(false) của script Bucket O' Magic:
    -- block nằm DƯỚI chân, chỉ lấy cột nằm trong pattern chéo, gần nhất.
    -- Really black + Smoky grey = blacklist: nếu block gần nhất là 1 trong 2 thì Farm:digPatternBlock tp lên TunnelTop (không đào).
    -- Có thể trả về block Really black (bedrock) -> Farm:dig sẽ tp lên TunnelTop.
    if amethyst then
        local bestPat, dPat = nil, math.huge
        for _, block in ipairs(blocks) do
            if block:IsA("BasePart") then
                local bp = block.Position
                if py > bp.Y then
                    local isMagic = (block.BrickColor.Name == "Royal purple" or self.magicSet[block])
                    if not (skipMagic and isMagic) then
                        local coord = block:GetAttribute('Coord')
                        if coord and pattern[coord.X * 100 + coord.Z] then
                            local d = (playerPos - bp).Magnitude
                            if d < dPat then bestPat, dPat = block, d end
                        end
                    end
                end
            end
        end
        return bestPat
    end

    local bestP, dP = nil, math.huge   -- block nằm trong pattern
    local bestA, dA = nil, math.huge   -- block hợp lệ bất kỳ (dự phòng)
    for _, block in ipairs(blocks) do
        if block:IsA("BasePart") then
            local bp = block.Position
            if py > bp.Y then
                local c = block.BrickColor.Name
                local valid
                if c == "Really black" then
                    valid = false
                elseif skipMagic and (c == "Royal purple" or self.magicSet[block]) then
                    valid = false
                elseif c == "Smoky grey" and skipSmoky then
                    valid = false
                elseif amethyst then
                    valid = true
                elseif mediumOnly then
                    valid = (c == "Medium blue")
                else
                    valid = (c == "Medium blue" or c == "Bright blue")
                end
                if valid then
                    local coord = block:GetAttribute('Coord')
                    if coord then
                        local d = (playerPos - bp).Magnitude
                        if pattern[coord.X * 100 + coord.Z] then
                            if d < dP then bestP, dP = block, d end
                        elseif d < dA then
                            bestA, dA = block, d
                        end
                    end
                end
            end
        end
    end
    return bestP or bestA
end

-- Digsite thường: block xếp theo lớp (Reddish brown trên cùng -> Cloudy grey -> Dark grey).
-- Ưu tiên đào đúng màu của shovel; nếu lớp đó chưa lộ ra thì đào các lớp phía trên để mở đường xuống.
function Farm:digsiteBlockColors()
    local sh = State.shovel
    if sh == "Flimsy Shovel" then return {"Reddish brown"} end
    if sh == "Normal Shovel" then return {"Cloudy grey", "Reddish brown"} end
    if sh == "Diamond Shovel" then
        -- Diamond: đào ALL block (Digsite + Advanced màu)
        if State.zonePhase == "ADVANCED" then
            return {"Medium blue", "Dark grey", "Cloudy grey", "Reddish brown", "Bright blue", "Medium stone grey", "Dark stone grey"}
        else
            return {"Dark grey", "Cloudy grey", "Reddish brown", "Medium stone grey", "Dark stone grey", "Brick yellow"}
        end
    end
    return {"Dark grey", "Cloudy grey", "Reddish brown"}  -- Bluesteel / Sharp / Pro
end

function Farm:findAnyBlock(blocks, playerPos)
    -- gom block gần nhất theo từng màu
    local nearest = {}
    for _, b in ipairs(blocks) do
        if b:IsA("BasePart") and b:GetAttribute('Coord') then
            local c = b.BrickColor.Name
            local d = (playerPos - b.Position).Magnitude
            if not nearest[c] or d < nearest[c].d then nearest[c] = {b = b, d = d} end
        end
    end
    -- lấy theo thứ tự ưu tiên màu
    for _, c in ipairs(self:digsiteBlockColors()) do
        if nearest[c] then return nearest[c].b end
    end
    return nil
end

-- Khi có block mà vẫn không chọn được block nào: in thống kê để biết lý do (class/màu/Coord/độ cao)
function Farm:diagBlocks(blocks, playerPos)
    if os.clock() - (self.lastDiag or 0) < 10 then return end
    self.lastDiag = os.clock()
    local classes, colors, withCoord = {}, {}, 0
    local minY, maxY = math.huge, -math.huge
    for _, b in ipairs(blocks) do
        classes[b.ClassName] = (classes[b.ClassName] or 0) + 1
        if b:IsA("BasePart") then
            local n = b.BrickColor.Name
            colors[n] = (colors[n] or 0) + 1
        end
        if b:GetAttribute('Coord') then withCoord = withCoord + 1 end
        local okp, pos = pcall(blockPos, b)
        if okp and pos then
            minY = math.min(minY, pos.Y)
            maxY = math.max(maxY, pos.Y)
        end
    end
    local function fmt(t)
        local out = {}
        for k, v in pairs(t) do out[#out + 1] = k .. "=" .. v end
        table.sort(out)
        return table.concat(out, ", ")
    end
    print(string.format('[DIGSITE][DIAG] findBlock=nil | want=%s (shovel=%s) | blocks=%d | withCoord=%d | classes{%s} | colors{%s} | blockY %.1f..%.1f | playerY %.1f',
        table.concat(self:digsiteBlockColors(), " > "), tostring(State.shovel), #blocks, withCoord, fmt(classes), fmt(colors), minY, maxY, playerPos.Y))
end

-- [NEW] Advanced: không tìm thấy block đúng màu -> đào TỪ TRÊN XUỐNG (block cao nhất) để mở đường tới block cần tìm
function Farm:digFromTop()
    -- Amethyst đào theo pattern (Bucket-style), không cần "đào từ trên xuống theo màu"
    if State.shovel == "Amethyst Shovel" then return false end
    local zone = getZoneObject(farmZoneName())
    if not zone then return false end
    local ok, blocks = pcall(function() return zone.Important.ActiveBlocks:GetChildren() end)
    if not ok or #blocks == 0 then return false end

    local char = game.Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local now = os.clock()
    local skipMagic = (State.shovel == "Amethyst Shovel" and self.phase ~= "MAGIC")
    local cands, maxY = {}, -math.huge
    for _, b in ipairs(blocks) do
        if b:IsA("BasePart") and b:GetAttribute('Coord') and (self.digIgnoreUntil[b] or 0) <= now then
            local c = b.BrickColor.Name
            local valid = self:isDiamondFullClear() or (c ~= "Really black" and not (c == "Smoky grey" and self:blockFirstShovel()))
            if valid and skipMagic and (c == "Royal purple" or self.magicSet[b]) then valid = false end
            if valid and not self:shouldSkipBlock(b) then
                cands[#cands + 1] = b
                if b.Position.Y > maxY then maxY = b.Position.Y end
            end
        end
    end

    if #cands == 0 then return false end

    -- Trong lớp trên cùng, chọn block gần người chơi nhất (đỡ phải bay xa)
    local best, bestD = nil, math.huge
    for _, b in ipairs(cands) do
        if b.Position.Y >= maxY - 1 then
            local d = (root.Position - b.Position).Magnitude
            if d < bestD then best, bestD = b, d end
        end
    end
    if not best then return false end

    -- Block không đào được (sai tier...) thì không kẹt mãi: thử vài lần rồi bỏ qua tạm
    local n = (self.digAttempts[best] or 0) + 1
    if n >= DIG_TOP_MAX_TRIES then
        self.digIgnoreUntil[best] = now + 15
        self.digAttempts[best] = 0
    else
        self.digAttempts[best] = n
    end

    if now - self.lastTopDigLog >= 5 then
        self.lastTopDigLog = now
        print(string.format('[DIGSITE] ⛏️ Không có block đúng màu → đào từ trên xuống (Y=%.1f, màu=%s)', best.Position.Y, best.BrickColor.Name))
    end
    self:dig(best)
    return true
end

-- Đếm thời gian liên tục ở 1 trạng thái (key); đủ BOTTOM_STAY_SECONDS mới trả true
function Farm:stayElapsed(key)
    local now = os.clock()
    self.stay[key] = self.stay[key] or now
    if now - self.stay[key] >= BOTTOM_STAY_SECONDS then
        self.stay[key] = nil
        return true
    end
    return false
end

function Farm:stayReset(key)
    self.stay[key] = nil
end

function Farm:blockFirstShovel()
    local s = State.shovel
    return s == "Diamond Shovel" or s == "Pro Shovel" or s == "Platinum Shovel" or s == "Emerald Shovel" or s == "Sapphire Shovel"
end

function Farm:isDiamondFullClear()
    return State.zonePhase == "ADVANCED" and State:ownsShovel("Diamond Shovel") and not State:ownsShovel("Amethyst Shovel")
end

function Farm:isDiamondUpgradePhase()
    return State.zonePhase == "ADVANCED"
        and State:ownsShovel("Diamond Shovel")
        and not State:ownsShovel("Amethyst Shovel")
end

function Farm:shouldSkipBlock(block)
    if not self:isDiamondUpgradePhase() or not block or not block:IsA("BasePart") then
        return false
    end
    local c = block.BrickColor.Name
    return c == "Medium blue" or c == "Really black"
end

function Farm:selectDiamondShaftColumn(blocks)
    if self.diamondShaftX ~= nil and self.diamondShaftZ ~= nil then
        return true
    end

    local candidates = {}
    local seen = {}

    for _, block in ipairs(blocks) do
        if block:IsA("BasePart") then
            local coord = block:GetAttribute("Coord")

            if coord then
                local x = math.floor(coord.X + 0.5)
                local y = math.floor(coord.Y + 0.5)
                local z = math.floor(coord.Z + 0.5)
                local color = block.BrickColor.Name

                if y == 1 and DIAMOND_TRANSIT_COLORS[color] then
                    local key = tostring(x) .. ":" .. tostring(z)

                    -- [NEW] bỏ qua cột đã gặp Really black
                    if not seen[key] and not self.diamondBadColumns[key] then
                        seen[key] = true
                        candidates[#candidates + 1] = {X = x, Z = z}
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        -- [NEW] hết cột để thử -> xóa danh sách cột hỏng để thử lại từ đầu
        if next(self.diamondBadColumns) ~= nil then
            print("[DIGSITE] ⚠️ Mọi cột đều bị chặn → reset danh sách cột hỏng")
            self.diamondBadColumns = {}
        end
        return false
    end

    local selected = candidates[math.random(1, #candidates)]
    self.diamondShaftX = selected.X
    self.diamondShaftZ = selected.Z

    print(string.format("[DIGSITE] DIAMOND SHAFT SELECTED | X=%d | Z=%d", self.diamondShaftX, self.diamondShaftZ))

    return true
end

function Farm:isDiamondTargetBlock(block, floor)
    if not block or not block:IsA("BasePart") then
        return false
    end

    local color = block.BrickColor.Name

    if color == "Lilac" then
        return floor >= DIAMOND_LILAC_MIN_FLOOR and floor <= DIAMOND_LILAC_MAX_FLOOR
    end

    if color == "Smoky grey" then
        return floor >= DIAMOND_SMOKY_MIN_FLOOR and floor <= DIAMOND_SMOKY_MAX_FLOOR
    end

    return false
end

function Farm:findDiamondDepthPath(blocks)
    if not self:isDiamondUpgradePhase() or self.diamondPathReached then
        return nil
    end

    if not self:selectDiamondShaftColumn(blocks) then
        return nil
    end

    local shaftX = self.diamondShaftX
    local shaftZ = self.diamondShaftZ
    local column = {}

    for _, block in ipairs(blocks) do
        if block:IsA("BasePart") then
            local coord = block:GetAttribute("Coord")

            if coord then
                local x = math.floor(coord.X + 0.5)
                local floor = math.floor(coord.Y + 0.5)
                local z = math.floor(coord.Z + 0.5)

                if x == shaftX and z == shaftZ then
                    column[#column + 1] = {block = block, floor = floor}
                end
            end
        end
    end

    if #column == 0 then
        return nil
    end

    table.sort(column, function(a, b)
        return a.floor < b.floor
    end)

    local entry = column[1]
    local block = entry.block
    local floor = entry.floor
    local color = block.BrickColor.Name

    if self:isDiamondTargetBlock(block, floor) then
        self.diamondPathReached = true
        self.diamondBlockedFloor = nil
        self.diamondBlockedCount = 0

        print(string.format(
            "[DIGSITE] ✓ DIAMOND TARGET FOUND | Color=%s | Floor=%d",
            color,
            floor
        ))

        return block, false
    end

    -- [A2] Chỉ Really black / Royal purple / màu lạ mới là chặn thật. Lilac/Smoky ngoài dải target vẫn đào xuyên qua được
    if floor <= DIAMOND_SMOKY_MAX_FLOOR and (DIAMOND_TRANSIT_COLORS[color] or DIAMOND_TARGET_COLORS[color]) then
        if os.clock() - self.lastDiamondPathLog >= 2 then
            self.lastDiamondPathLog = os.clock()

            print(string.format(
                "[DIGSITE] DIAMOND SHAFT | X=%d Z=%d | Floor=%d/50 | Color=%s",
                shaftX, shaftZ, floor, color
            ))
        end

        return block, true
    end

    -- [NEW] Gặp Really black (hoặc block không đào được) -> bỏ cột này, tp lên TunnelTop, chọn X/Z khác
    print(string.format(
        "[DIGSITE] ⚠️ SHAFT X=%d Z=%d bị chặn | Floor=%d | Color=%s → TP TunnelTop, chọn cột khác",
        shaftX, shaftZ, floor, color
    ))
    self.diamondBadColumns[tostring(shaftX) .. ":" .. tostring(shaftZ)] = true
    self.diamondShaftX = nil
    self.diamondShaftZ = nil

    -- Chặn liên tiếp ở cùng 1 tầng => khu magic block. Đang ở diamond farm không cần magic => HOP
    if self.diamondBlockedFloor == floor then
        self.diamondBlockedCount = self.diamondBlockedCount + 1
    else
        self.diamondBlockedFloor = floor
        self.diamondBlockedCount = 1
    end

    if self.diamondBlockedCount >= DIAMOND_BLOCK_HOP_AFTER then
        print(string.format(
            "[DIGSITE] 🔁 Chặn liên tiếp %d lần ở tầng %d (khu magic block) → HOP server",
            self.diamondBlockedCount, floor
        ))
        self.diamondBlockedFloor = nil
        self.diamondBlockedCount = 0
        self.phase = "HOP"
        return nil
    end

    self.lastTopTp = 0   -- bỏ cooldown 2s để chắc chắn tele
    self:tpTop("shaft gặp " .. color .. " ở tầng " .. floor)
    return nil
end

function Farm:onlyMediumBlue()
    return State.shovel == "Pro Shovel" or State.shovel == "Platinum Shovel"
end

function Farm:atBrightBlue()
    local zone = getZoneObject(farmZoneName())
    local char = game.Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (zone and root) then return false end

    local p = root.Position
    local best, bestDy = nil, math.huge
    local ok, blocks = pcall(function() return zone.Important.ActiveBlocks:GetChildren() end)
    if not ok then return false end

    for _, b in ipairs(blocks) do
        if b:IsA("BasePart") and b.Position.Y < p.Y then
            if math.abs(b.Position.X - p.X) <= 4 and math.abs(b.Position.Z - p.Z) <= 4 then
                local dy = p.Y - b.Position.Y
                if dy < bestDy then
                    best, bestDy = b, dy
                end
            end
        end
    end
    return best ~= nil and best.BrickColor.Name == "Bright blue"
end

function Farm:tpTop(reason)
    if os.clock() - self.lastTopTp < 2 then return end
    self.lastTopTp = os.clock()

    local ok, err = pcall(function()
        local root = game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
        if farmZoneName() == "Digsite" then
            root.CFrame = DIGSITE_TOP_CFRAME   -- Digsite thường: tp thẳng tới điểm đã đo
            return
        end
        local tunnelTop = self:getTunnelTop()
        if tunnelTop then
            root.CFrame = tunnelTop.CFrame
        else
            -- Digsite thường có thể không có TunnelTop -> lên trên block cao nhất
            local zone = getZoneObject(farmZoneName())
            local top = nil
            for _, b in ipairs(zone.Important.ActiveBlocks:GetChildren()) do
                if b:IsA("BasePart") and (not top or b.Position.Y > top.Position.Y) then top = b end
            end
            if not top then error("no TunnelTop and no blocks in " .. farmZoneName()) end
            root.CFrame = CFrame.new(top.Position + Vector3.new(0, 6, 0))
        end
    end)
    print('[DIGSITE] ⬆️ TP lên TunnelTop (' .. tostring(reason) .. ')' .. (ok and '' or (' | lỗi: ' .. tostring(err))))
end

function Farm:atBottom()
    local now = os.clock()
    if self._bottomAt and now - self._bottomAt < 0.5 then return self._bottomVal end
    self._bottomAt = now
    self._bottomVal = self:atBottomRaw()
    return self._bottomVal
end

function Farm:atBottomRaw()
    local zone = getZoneObject(farmZoneName())
    local char = game.Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (zone and root) then return false end

    local ok, blocks = pcall(function() return zone.Important.ActiveBlocks:GetChildren() end)
    if not ok then return false end

    local p = root.Position
    local below, belowDy = nil, math.huge
    local lowestY = math.huge
    for _, b in ipairs(blocks) do
        if b:IsA("BasePart") then
            if b.Position.Y < lowestY then lowestY = b.Position.Y end
            if b.Position.Y < p.Y and math.abs(b.Position.X - p.X) <= 4 and math.abs(b.Position.Z - p.Z) <= 4 then
                local dy = p.Y - b.Position.Y
                if dy < belowDy then below, belowDy = b, dy end
            end
        end
    end

    if State.zonePhase ~= "DIGSITE" and below and belowDy <= 12 and not self:isDiamondFullClear() and (below.BrickColor.Name == "Really black" or below.BrickColor.Name == "Smoky grey") then return true end
    if lowestY ~= math.huge and p.Y < lowestY - 8 then return true end
    return false
end

-- Các block cùng màu nằm gần `block` (để đào hàng loạt trong 1 lần)
function Farm:nearbyBlocks(block, n)
    local zone = getZoneObject(farmZoneName())
    if not zone then return {} end
    local ok, blocks = pcall(function() return zone.Important.ActiveBlocks:GetChildren() end)
    if not ok then return {} end
    local origin = blockPos(block)
    local list = {}

    -- Diamond Full Clear: batch toàn bộ block gần, không filter màu (trừ Medium blue trong upgrade phase)
    if self:isDiamondFullClear() then
        for _, b in ipairs(blocks) do
            if b ~= block
                and b:IsA("BasePart")
                and b:GetAttribute('Coord')
                and not self:shouldSkipBlock(b) then

                local d = (b.Position - origin).Magnitude
                if d <= DIG_BATCH_RADIUS then list[#list + 1] = {b = b, d = d} end
            end
        end
    else
        -- Normal: batch toàn bộ block cùng màu
        local color = block:IsA("BasePart") and block.BrickColor.Name or nil
        for _, b in ipairs(blocks) do
            if b ~= block and b:IsA("BasePart") and b.BrickColor.Name == color and b:GetAttribute('Coord') then
                local d = (b.Position - origin).Magnitude
                if d <= DIG_BATCH_RADIUS then list[#list + 1] = {b = b, d = d} end
            end
        end
    end

    table.sort(list, function(a, c) return a.d < c.d end)
    local out = {}
    for k = 1, math.min(n, #list) do out[k] = list[k].b end
    return out
end

function Farm:dig(block, allowDiamondTransitPath)
    -- Amethyst: block được chọn theo pattern là bedrock (Really black) -> lên TunnelTop (giống script Bucket)
    if State.shovel == "Amethyst Shovel" and (block.BrickColor == BEDROCK_COLOR or block.BrickColor.Name == "Smoky grey") then
        self.lastTopTp = 0
        self:tpTop("chạm bedrock/smoky grey")
        task.wait(0.5)
        return
    end

    if self:isDiamondUpgradePhase() and allowDiamondTransitPath then
        local color = block.BrickColor.Name

        if not DIAMOND_TRANSIT_COLORS[color]
            and not DIAMOND_TARGET_COLORS[color] then
            return
        end
    elseif self:shouldSkipBlock(block) then
        return
    end

    local remote = getFireRemote()
    local coord = block:GetAttribute('Coord')
    if not coord then return end

    local lp = game.Players.LocalPlayer
    local zoneName = farmZoneName()
    local function step()
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = block.CFrame + Vector3.new(0, 3, 0)
        for _ = 1, DIG_FIRES_PER_TICK do
            remote:FireServer(zoneName, "DigBlock", coord)
        end
    end

    local startTime = tick()
    repeat
        pcall(step)
        task.wait()
    until not block.Parent or tick() - startTime > 7
end

-- Đào 1 block giống script Bucket O' Magic: tp lên trên block rồi bắn ĐÚNG 1 lệnh DigBlock, chờ 0.05s rồi trả về
-- (vòng lặp bên ngoài chọn lại block gần nhất ở lần sau).
--   magic   : block.CFrame + (0, 3, 0)
--   pattern : CFrame.new(block.Position + (0, 4, 0))
function Farm:digOnce(block, yOffset, useBlockCFrame)
    local coord = block:GetAttribute('Coord')
    local root = getRootPart()
    if not (coord and root) then
        task.wait(0.05)
        return
    end
    if useBlockCFrame then
        root.CFrame = block.CFrame + Vector3.new(0, yOffset, 0)
    else
        root.CFrame = CFrame.new(block.Position + Vector3.new(0, yOffset, 0))
    end
    pcall(function()
        getFireRemote():FireServer(farmZoneName(), "DigBlock", coord)
    end)
    task.wait(0.05)
end

-- Đào block theo pattern chéo tìm pool (CHEST/REFILL). Amethyst dùng cách của script Bucket, shovel khác giữ cách cũ.
function Farm:digPatternBlock(block, allowTransit)
    if State.shovel == "Amethyst Shovel" then
        if block.BrickColor == BEDROCK_COLOR or block.BrickColor.Name == "Smoky grey" then
            -- chạm bedrock / smoky grey (blacklist) -> lên TunnelTop
            self.lastTopTp = 0
            self:tpTop("chạm bedrock/smoky grey")
            task.wait(0.5)
            return
        end
        self:digOnce(block, 4, false)
    else
        self:dig(block, allowTransit)
    end
end

-- Cách mở chest giống script Bucket O' Magic: tp lên chest.Top, bắn 1 lệnh DigChest, chờ 0.05s rồi trả về
-- (vòng lặp bên ngoài chọn lại chest gần nhất ở lần sau, không bỏ qua chest nào).
function Farm:openChest(chest)
    local coord = chest:GetAttribute('Coord')
    local root = getRootPart()
    local top = chest:FindFirstChild("Top")
    if not (coord and root and top) then
        task.wait(0.05)
        return
    end
    -- [B4] chest không mở được sau N lần -> bỏ qua tạm, để timer chestTimeout/HOP còn chạy được
    local n = (self.chestAttempts[chest] or 0) + 1
    if n >= CHEST_MAX_ATTEMPTS then
        self.chestAttempts[chest] = 0
        self.chestIgnoreUntil[chest] = os.clock() + CHEST_IGNORE_SECONDS
        print(string.format('[DIGSITE] ⚠️ Chest không mở được sau %d lần → bỏ qua %ds', CHEST_MAX_ATTEMPTS, CHEST_IGNORE_SECONDS))
    else
        self.chestAttempts[chest] = n
    end
    root.CFrame = top.CFrame
    pcall(function()
        getFireRemote():FireServer(farmZoneName(), "DigChest", coord)
    end)
    task.wait(0.05)
end

function Farm:logEvent(event)
    if State.shovel == "Amethyst Shovel" then
        print('[DIGSITE] ' .. event)
    end
end

function Farm:runPhase1()
    -- CHEST phase: ưu tiên chest giống Amethyst.
    -- Diamond Full Clear vẫn đào toàn bộ block khi không còn chest hợp lệ.

    local diamondFullClear = self:isDiamondFullClear()
    local blockFirst = self:blockFirstShovel()
    local chest = self:findChest()

    -- Diamond là ngoại lệ: dù blockFirst=true vẫn phải farm chest trước.
    -- Các shovel khác giữ nguyên hành vi cũ.
    local chestFirst = (not blockFirst) or diamondFullClear

    if chest and chestFirst then
        self.diamondIdleSince = nil   -- [A1] đang mở chest = có việc làm
        self.lastChestTime = os.clock()
        self:openChest(chest)
        return
    end

    local magicBlock = State.shovel == "Amethyst Shovel" and self:findMagicBlock() or nil
    if magicBlock then
        local bucket = State:getBucketCount()

        if bucket <= 0 then
            print('[DIGSITE] ⚠️ Magic found but Bucket empty → REFILL/HOP')
            self:beginRefill()
            return
        end

        print('[DIGSITE] Found magic block during chest farming → switching to MAGIC phase')
        self.chestWaitStart = nil
        self.phase = "MAGIC"
        self.lastBlockCheckTime = os.clock()
        return
    end

    -- Amethyst: có pool nhưng toàn nằm TRÊN đầu (đã đào qua) -> findMagicBlock (chỉ lấy block dưới chân) không thấy.
    -- Lên TunnelTop để pool nằm dưới chân thay vì đào xuống xa pool. Cách nhau tối thiểu 10s để không lặp.
    if State.shovel == "Amethyst Shovel" and not magicBlock and next(self.magicSet) ~= nil
        and os.clock() - (self.lastPoolTopTp or 0) >= 10 then
        self.lastPoolTopTp = os.clock()
        self.lastTopTp = 0
        self:tpTop("pool magic nằm trên đầu")
        task.wait(0.3)
        return
    end

    if State.shovel == "Amethyst Shovel" and os.clock() - self.lastChestTime >= self.chestTimeout then
        print('[DIGSITE] No chest for ' .. tostring(self.chestTimeout) .. 's → HOP')
        self.phase = "HOP"
        return
    end

    -- Digsite thường: block chưa sinh ra (ActiveBlocks rỗng) -> chờ, quá lâu thì rejoin (không phải "hết block")
    if State.zonePhase == "DIGSITE" and not chest and self:countBlocks() == 0 then
        self.noBlocksSince = self.noBlocksSince or os.clock()
        local waited = os.clock() - self.noBlocksSince
        if os.clock() - (self.lastNoBlocksLog or 0) >= 5 then
            self.lastNoBlocksLog = os.clock()
            print(string.format('[DIGSITE] ⏳ ActiveBlocks=0, chờ block sinh ra %.0fs/%ds...', waited, BLOCKS_WAIT_TIMEOUT))
        end
        if waited >= BLOCKS_WAIT_TIMEOUT then
            self.noBlocksSince = nil
            print('[DIGSITE] ⚠️ Không có block sau ' .. BLOCKS_WAIT_TIMEOUT .. 's → rejoin Digsite')
            Transition:rejoinCurrent("no_blocks")
            return
        end
        task.wait(1)
        return
    end
    self.noBlocksSince = nil

    if self:onlyMediumBlue() and self:atBrightBlue() then
        self:tpTop("chạm Bright blue")
        return
    end

    if self:atBottom() then
        if self:stayElapsed("bottom") then
            self:tpTop("ở tầng đáy ≥ " .. BOTTOM_STAY_SECONDS .. "s")
            return
        end
        -- chưa đủ thời gian: tiếp tục farm ở tầng đáy, chưa tele
    else
        self:stayReset("bottom")
    end

    local block, allowMediumBluePath = self:findBlock()
    if block then
        self:stayReset("noblock")
        self.diamondIdleSince = nil   -- [A1] có block để đào -> reset mốc idle
        self:digPatternBlock(block, allowMediumBluePath)
        return
    end

    -- [A1] Diamond Upgrade không tìm được mục tiêu: chờ ActiveBlocks cập nhật, quá DIAMOND_IDLE_SECONDS thì xử lý chủ động
    if self:isDiamondUpgradePhase() then
        self.diamondIdleSince = self.diamondIdleSince or os.clock()
        local idle = os.clock() - self.diamondIdleSince
        if idle >= DIAMOND_IDLE_SECONDS then
            self.diamondIdleSince = nil
            if self.diamondPathReached then
                print('[DIGSITE] 🔁 Diamond: hết Lilac/Smoky target ' .. DIAMOND_IDLE_SECONDS .. 's → HOP')
                self.phase = "HOP"
            else
                print('[DIGSITE] ⚠️ Diamond: shaft không có block ' .. DIAMOND_IDLE_SECONDS .. 's → rejoin')
                Transition:rejoinCurrent("diamond_idle")
            end
            return
        end
        task.wait(0.25)
        return
    end

    -- Hết block để đào -> đi mở chest (kể cả chest xa)
    if chest then
        self.lastChestTime = os.clock()
        self:openChest(chest)
        return
    end

    if State.zonePhase == "DIGSITE" then
        task.wait(0.2)   -- chưa có block đúng màu của shovel -> chờ (giống V2), không tpTop
        return
    end

    if self:digFromTop() then self:stayReset("noblock") return end   -- [NEW] Advanced: đào từ trên xuống để tìm block
    if State.shovel == "Amethyst Shovel" then
        -- Amethyst: không còn block pattern nào dưới chân (hoặc block chưa sinh ra)
        if self:countBlocks() == 0 then
            task.wait(0.25)
            return
        end
        self:tpTop("không còn block pattern dưới chân")
        task.wait(0.5)
        return
    end

    if self:stayElapsed("noblock") then
        self:tpTop("hết block ≥ " .. BOTTOM_STAY_SECONDS .. "s")
    end
    task.wait(0.5)
end

function Farm:runPhase2()
    -- Cách đào magic giống script Bucket O' Magic: check Bucket, tp lên trên block 3 stud, bắn 1 lệnh,
    -- mỗi vòng chọn lại magic block gần nhất.
    if State:getBucketCount() <= 0 then
        self:beginRefill()
        return
    end

    local magicBlock = self:findMagicBlock()
    if magicBlock then
        self:digOnce(magicBlock, 3, true)
        self.foundSparkles = true
        return
    end

    local bucket = State:getBucketCount()

    self.magicToChestCount = self.magicToChestCount + 1
    self.phase = "CHEST"
    self.lastChestTime = os.clock()
    self.chestWaitStart = os.clock()
    self:logEvent(string.format(
        "Hết magic (còn Bucket=%d) → CHEST lần %d%s",
        bucket,
        self.magicToChestCount,
        self.magicToChestCount >= 2 and (" | không thấy magic trong " .. self.chestRetryTimeout .. "s → HOP") or ""
    ))
end

function Farm:runPhase3()
    local bucket = State:getBucketCount()

    if bucket >= 3 then
        self.afterRefill = true
        self.refillStartedAt = nil
        self.phase = "MAGIC"
        self:logEvent("Got 3 Buckets → Resume MAGIC")
        return
    end

    if not self.refillStartedAt then
        self.refillStartedAt = os.clock()
    end

    local elapsed = os.clock() - self.refillStartedAt

    if elapsed >= 180 then
        self.phase = "HOP"
        self:logEvent(string.format("REFILL timeout after 180s | Bucket=%d/3 → HOP", bucket))
        return
    end

    local chest = self:findChest()
    if chest then
        self:openChest(chest)
        return
    end

    if self:onlyMediumBlue() and self:atBrightBlue() then
        self:tpTop("chạm Bright blue")
        task.wait(0.5)
        return
    end

    if self:atBottom() then
        if self:stayElapsed("bottom") then
            self:tpTop("ở tầng đáy ≥ " .. BOTTOM_STAY_SECONDS .. "s")
            return
        end
        -- chưa đủ thời gian: tiếp tục farm ở tầng đáy, chưa tele
    else
        self:stayReset("bottom")
    end

    local block, allowMediumBluePath = self:findBlock()
    if block then
        self:stayReset("noblock")
        self:digPatternBlock(block, allowMediumBluePath)
        return
    end

    if self:digFromTop() then self:stayReset("noblock") return end   -- [NEW] đào từ trên xuống để tìm block
    if State.shovel == "Amethyst Shovel" then
        -- Amethyst: không còn block pattern nào dưới chân (hoặc block chưa sinh ra)
        if self:countBlocks() == 0 then
            task.wait(0.25)
            return
        end
        self:tpTop("không còn block pattern dưới chân")
        task.wait(0.5)
        return
    end

    if self:stayElapsed("noblock") then
        self:tpTop("hết block ≥ " .. BOTTOM_STAY_SECONDS .. "s")
    end
    task.wait(0.5)
end

function Farm:run()
    local zone = getZoneObject(farmZoneName())
    if not zone then
        task.wait(0.5)
        return
    end

    local ok, ready = pcall(function()
        return zone:FindFirstChild("Important") and zone.Important:FindFirstChild("ActiveChests") and zone.Important:FindFirstChild("ActiveBlocks")
    end)

    if not (ok and ready) then
        task.wait(0.5)
        return
    end

    self:bindZone()

    if self.pendingTopTp and State.shovel == "Amethyst Shovel" then
        self.pendingTopTp = false
        self.lastTopTp = 0
        self:tpTop("vừa chuyển sang Amethyst")
        task.wait(0.3)
    end

    local rescanEvery = (State.shovel == "Amethyst Shovel") and MAGIC_RESCAN_SECONDS or 5
    if os.clock() - self.lastRescan >= rescanEvery then
        self:rescanMagic()
    end

    self:checkEvery20s()

    if State.shovel == "Amethyst Shovel" and (self.phase == "CHEST" or self.phase == "MAGIC") then
        local now = os.clock()
        self.lastPoolSeenAt = self.lastPoolSeenAt or now
        if now - self.lastPoolCheck >= 1 then
            self.lastPoolCheck = now
            if self:hasMagicPool() == true then
                self.lastPoolSeenAt = now
            elseif now - self.lastPoolSeenAt >= self.poolTimeout then
                self.phase = "HOP"
                self:logEvent(string.format("Không thấy pool Royal purple trong %ds → HOP", self.poolTimeout))
            end
        end
    end

    if State.shovel == "Amethyst Shovel" and self.phase == "CHEST" and self.magicToChestCount >= 2
        and self.chestWaitStart and os.clock() - self.chestWaitStart >= self.chestRetryTimeout then
        self.phase = "HOP"
        self:logEvent(string.format("CHEST lần %d: không thấy magic trong %ds → HOP", self.magicToChestCount, self.chestRetryTimeout))
    end

    if self.phase == "HOP" then
        print('[DIGSITE] Farm: awaiting server hop...')
        task.wait(1)
        return
    end

    if self.phase == "CHEST" or not self.phase then
        self:runPhase1()
    elseif self.phase == "MAGIC" then
        self:runPhase2()
    elseif self.phase == "REFILL" then
        self:runPhase3()
    end
end

-- [FIX] Bọc pcall: 1 lỗi (character chưa có, block bị destroy...) không làm chết cả script
local function farmStep()
    local ok, err = pcall(Farm.run, Farm)
    if not ok then
        print('[DIGSITE] ❌ Farm error: ' .. tostring(err))
        task.wait(1)
    end
end

-- =========== PURCHASE ===========
local Purchase = {}
Purchase.fails = {}

function Purchase:buy(shovelName)
    State:update(true)
    if State:ownsShovel(shovelName) then
        print(string.format('[DIGSITE] ✓ Already own %s, skip buy', shovelName))
        return true
    end

    print(string.format('[DIGSITE] → Attempting to buy %s...', shovelName))

    local Network = game:GetService("ReplicatedStorage"):WaitForChild("Network")
    local remote = Network:FindFirstChild("DigsiteMerchant_PurchaseShovel")

    if not remote then
        print('[DIGSITE] ❌ Purchase remote not found')
        return false
    end

    local ok, result = pcall(function()
        return remote:InvokeServer(shovelName)
    end)

    if ok then
        local coinsBefore = State.coins
        print(string.format('[DIGSITE] Invoke returned: %s', tostring(result)))
        task.wait(3)
        State:update(true)

        if State:ownsShovel(shovelName) then
            Purchase.fails[shovelName] = nil
            print(string.format('[DIGSITE] ✓ Confirmed: %s in inventory', shovelName))
            return true
        end

        local dropped = coinsBefore - State.coins
        -- [FIX] shovel giá 0 (Flimsy): 0 >= 0 luôn đúng -> trước đây luôn "xác nhận" giả. Chỉ xác nhận bằng inventory.
        if shovelPrice(shovelName) > 0 and dropped >= shovelPrice(shovelName) * 0.5 then
            State.confirmed[shovelName] = true
            State:update(true)
            print(string.format('[DIGSITE] ✓ Confirmed (coin -%d): %s', dropped, shovelName))
            return true
        end

        local n = (Purchase.fails[shovelName] or 0) + 1
        Purchase.fails[shovelName] = n
        print(string.format('[DIGSITE] ⚠️ Coin không bị trừ (lần %d): %s', n, shovelName))
        if n >= 2 then
            State.confirmed[shovelName] = true
            State:update(true)
            print(string.format('[DIGSITE] ✓ Coi như đã sở hữu %s (mua %d lần không trừ coin)', shovelName, n))
            return true
        end
        return false
    else
        print(string.format('[DIGSITE] ❌ Purchase failed: %s', tostring(result)))
        return false
    end
end

-- =========== TRANSITION ===========
Transition = {
    failedServers = {}
}

function Transition:exitToMainWorld(reason)
    print("[DIGSITE] → Exiting to Main World | Reason: " .. tostring(reason))

    for attempt = 1, 3 do
        if isMainWorld() then
            print("[DIGSITE] ✓ Already in Main World")
            return true
        end

        print(string.format(
            "[DIGSITE] Exit instance attempt %d/3",
            attempt
        ))

        pcall(function()
            if inInstanceNow() then
                Instancing.Exit()
            end
        end)

        local started = os.clock()

        repeat
            if isMainWorld() then
                print("[DIGSITE] ✓ Successfully exited to Main World")
                return true
            end

            task.wait(0.25)
        until os.clock() - started >= 8
    end

    print("[DIGSITE] ⚠️ Cannot exit instance normally → rejoining same server")

    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(
            game.PlaceId,
            game.JobId,
            Players.LocalPlayer
        )
    end)

    return false
end

function Transition:joinCurrentPhaseZone(reason)
    local targetZone = State.zonePhase == "ADVANCED"
        and "AdvancedDigsite"
        or "Digsite"

    print(string.format(
        "[DIGSITE] → Rejoining current phase | Phase=%s | Target=%s | Reason=%s",
        tostring(State.zonePhase),
        targetZone,
        tostring(reason)
    ))

    for attempt = 1, 3 do
        print(string.format(
            "[DIGSITE] Join %s attempt %d/3",
            targetZone,
            attempt
        ))

        local ok, err = pcall(function()
            if targetZone == "AdvancedDigsite" then
                Instancing.Enter("AdvancedDigsite")
            else
                local enter = game.Workspace
                    .__THINGS.Instances.Digsite.Teleports:FindFirstChild("Enter")

                local character = Players.LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")

                if enter and root then
                    root.CFrame = enter.CFrame
                else
                    Instancing.Enter("Digsite")
                end
            end
        end)

        if not ok then
            print("[DIGSITE] Join error: " .. tostring(err))
        end

        if waitForZoneReady(targetZone, 30, true) then
            local valid, issue = inspectZoneStructure(targetZone)

            if valid and resolveActiveZone() == targetZone then
                print("[DIGSITE] ✓ Successfully joined " .. targetZone)
                return true
            end

            print("[DIGSITE] ⚠️ Zone still invalid: " .. tostring(issue))
        else
            print("[DIGSITE] ⚠️ Zone loading timeout: " .. targetZone)
        end

        if attempt < 3 then
            pcall(function()
                if inInstanceNow() then
                    Instancing.Exit()
                end
            end)

            local t0 = os.clock()
            repeat
                task.wait(0.25)
            until isMainWorld() or os.clock() - t0 >= 8
        end
    end

    print("[DIGSITE] ❌ Unable to rejoin " .. targetZone)
    return false
end

function Transition:recoverCurrentPhase(reason)
    if Farm.phase == "HOP" then
        print("[DIGSITE] HOP already pending, skip zone recovery")
        return false
    end

    local savedZonePhase = State.zonePhase
    local savedFarmPhase = Farm.phase

    print(string.format(
        "[DIGSITE] ⚠️ ZONE RECOVERY | Zone=%s | FarmPhase=%s | Reason=%s",
        tostring(savedZonePhase),
        tostring(savedFarmPhase),
        tostring(reason)
    ))

    if not self:exitToMainWorld(reason) then
        return false
    end

    State.zonePhase = savedZonePhase

    if not self:joinCurrentPhaseZone(reason) then
        print("[DIGSITE] ❌ Recovery failed")
        return false
    end

    for _, connection in ipairs(Farm.conns) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    Farm.conns = {}
    Farm.boundBlocks = nil
    Farm.magicSet = {}
    Farm.blockCount = 0
    Farm.lastRescan = 0

    Farm.chestAttempts = setmetatable({}, {__mode = "k"})
    Farm.chestIgnoreUntil = setmetatable({}, {__mode = "k"})
    Farm.digAttempts = setmetatable({}, {__mode = "k"})
    Farm.digIgnoreUntil = setmetatable({}, {__mode = "k"})

    Farm.stay = {}
    Farm.lastChestTime = os.clock()
    Farm.lastPoolSeenAt = os.clock()
    Farm.lastPoolCheck = 0
    Farm.lastPeriodicCheck = 0
    Farm.chestWaitStart = nil

    if savedFarmPhase == "CHEST"
        or savedFarmPhase == "MAGIC"
        or savedFarmPhase == "REFILL" then

        Farm.phase = savedFarmPhase
    else
        Farm.phase = "CHEST"
    end

    if Farm.phase == "REFILL" then
        Farm.refillStartedAt = os.clock()
    end

    Farm.diamondShaftX = nil
    Farm.diamondShaftZ = nil
    Farm.diamondBadColumns = {}   -- [NEW] map sinh lại -> xóa cột hỏng
    Farm.diamondBlockedFloor = nil
    Farm.diamondBlockedCount = 0
    Farm.diamondPathReached = false
    Farm.diamondIdleSince = nil   -- [A1]

    State:update(true)
    State:resetStuck()

    State.zoneBadSince = nil
    State.rejoinFails = 0
    State.rejoinAdvancedFails = 0

    dumpZone(savedZonePhase == "ADVANCED" and "AdvancedDigsite" or "Digsite")

    if savedZonePhase == "ADVANCED" then
        diagnosticAdvancedBlocks("AdvancedDigsite")
    end

    print(string.format(
        "[DIGSITE] ✓ RECOVERY COMPLETE | Zone=%s | Resumed FarmPhase=%s",
        tostring(State.zonePhase),
        tostring(Farm.phase)
    ))

    return true
end

function Transition:enterAdvancedAndSync(reason)
    print('[DIGSITE] → Entering AdvancedDigsite (' .. tostring(reason) .. ')...')

    if not joinAdvancedDigsite() then
        print('[DIGSITE] ❌ Failed to join Advanced')
        return false
    end

    print('[DIGSITE] Waiting for AdvancedDigsite zone to fully load...')
    if not waitForZoneReady("AdvancedDigsite", 30) then
        print('[DIGSITE] ⚠️ AdvancedDigsite zone not ready after 30s')
        return false
    end

    State:update(true)
    State.zonePhase = "ADVANCED"
    Farm.phase = "CHEST"
    Farm.lastChestTime = os.clock()
    Farm.foundSparkles = false
    -- [B3] KHÔNG reset refillUsed/afterRefill ở đây: rejoin liên tục sẽ được refill vô hạn. Chỉ reset trong Farm:resetForAmethyst
    Farm.magicToChestCount = 0
    Farm.chestWaitStart = nil
    Farm.lastPoolSeenAt = nil
    Farm.lastPoolCheck = 0
    Farm.diamondShaftX = nil          -- [NEW] vào zone mới -> chọn lại cột
    Farm.diamondShaftZ = nil
    Farm.diamondBadColumns = {}       -- [NEW] map sinh lại -> xóa cột hỏng
    Farm.diamondBlockedFloor = nil
    Farm.diamondBlockedCount = 0
    Farm.diamondPathReached = false
    Farm.diamondIdleSince = nil       -- [A1]
    Farm.lastDiamondPathLog = 0
    Farm.lastDiamondTargetLog = 0
    State:resetStuck()

    dumpZone("AdvancedDigsite")
    diagnosticAdvancedBlocks("AdvancedDigsite")
    task.spawn(boostDigsiteFPS)
    print('[DIGSITE] ✓ In Advanced Digsite, farm reset to CHEST phase, State.zonePhase = ADVANCED')
    return true
end

function Transition:rejoinAdvanced(reason)
    print('[DIGSITE] ⚠️ Rejoining AdvancedDigsite (' .. tostring(reason) .. ')...')
    leaveInstance("AdvancedDigsite")   -- luôn thoát hẳn, kể cả khi zone đã hỏng
    return self:enterAdvancedAndSync("rejoin_" .. tostring(reason))
end

-- [FIX] Rejoin đúng zone hiện tại (trước đây Flimsy bị ép vào Advanced)
function Transition:rejoinCurrent(reason)
    if State.zonePhase == "ADVANCED" then
        return self:rejoinAdvanced(reason)
    end

    print('[DIGSITE] ⚠️ Rejoining Digsite (' .. tostring(reason) .. ')...')
    pcall(function()
        if Instancing.IsInInstance() then Instancing.Exit() end
    end)
    task.wait(2)

    self.rejoinCount = (self.rejoinCount or 0) + 1
    if self.rejoinCount % 2 == 0 then
        print('[DIGSITE] Rejoin bằng Instancing.Enter("Digsite")')
        pcall(function() Instancing.Enter("Digsite") end)
        task.wait(3)
    else
        pcall(function()
            local enter = game:GetService("Workspace").__THINGS.Instances.Digsite.Teleports:FindFirstChild("Enter")
            local root = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
            if enter then root.CFrame = enter.CFrame end
        end)
    end

    local ready = waitForZoneReady("Digsite", 30, true)
    print('[DIGSITE] Digsite zone ready after rejoin: ' .. tostring(ready))
    State:update(true)
    State:resetStuck()
    dumpZone("Digsite")
    return ready
end

-- Lấy danh sách server khả dụng theo thứ tự: "Asc" = ÍT người nhất trước, "Desc" = NHIỀU người nhất trước
function Transition:fetchServers(order, minFree)
    local Http = game:GetService("HttpService")
    local base = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true",
        game.PlaceId, order
    )
    local list, cursor = {}, nil
    local apiFailed = false

    for page = 1, HOP_MAX_PAGES do
        local url = base .. (cursor and ("&cursor=" .. cursor) or "")
        local data = nil

        for attempt = 1, 2 do
            local ok, res = pcall(function()
                return Http:JSONDecode(game:HttpGet(url))
            end)
            if ok and type(res) == "table" and type(res.data) == "table" then
                data = res
                break
            end
            print(string.format('[DIGSITE] ⚠️ API %s page %d lỗi (lần %d), thử lại...', order, page, attempt))
            if attempt < 2 then task.wait(3) end  -- ít retry để không làm 429 nặng thêm
        end

        if not data then apiFailed = true break end

        for _, server in ipairs(data.data) do
            local maxP = server.maxPlayers or 25
            if server.id ~= game.JobId
                and not self.failedServers[server.id]
                and (server.playing or 0) <= maxP - minFree then
                list[#list + 1] = server
            end
        end

        cursor = data.nextPageCursor
        if not cursor then break end
        if #list >= 30 then break end  -- đủ lựa chọn, khỏi quét thêm
        task.wait(0.5)
    end

    return list, apiFailed
end

function Transition:hopToRandomServer()
    print('[DIGSITE] → Hopping to random server...')

    local TPS = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local picked, mode = nil, nil

    for round = 1, 2 do
        -- 1) ưu tiên server ÍT người
        local list, apiFailed = self:fetchServers("Asc", 1)
        mode = "ÍT người"

        -- API lỗi / bị 429: gọi thêm chỉ làm tệ hơn -> bỏ qua lượt hop thủ công này
        if apiFailed and #list == 0 then
            print('[DIGSITE] ⚠️ API Roblox lỗi/429 → bỏ qua hop thủ công lượt này')
            break
        end

        -- 2) hết server ít người (API vẫn OK) -> chuyển sang API server NHIỀU người
        if #list == 0 then
            print('[DIGSITE] ⚠️ Hết server ít người → chuyển sang danh sách server NHIỀU người')
            list = self:fetchServers("Desc", HOP_FREE_SLOTS_MOST)
            mode = "NHIỀU người"
        end

        if #list > 0 then
            math.randomseed(os.time() + round)
            picked = list[math.random(1, #list)]
            break
        end

        -- 3) cả hai đều hết -> xóa danh sách server đã fail rồi quét lại 1 lần
        if next(self.failedServers) == nil then break end
        print('[DIGSITE] ⚠️ Hết server khả dụng → reset failedServers và quét lại')
        self.failedServers = {}
    end

    if not picked then
        print('[DIGSITE] ❌ No suitable server found (cả ÍT và NHIỀU người)')
        return false
    end

    print(string.format('[DIGSITE] Selected server %s (%s) %d/%d players',
        picked.id:sub(1, 8), mode, picked.playing or 0, picked.maxPlayers or 25))

    local teleportFailed = false
    local conn = TPS.TeleportInitFailed:Connect(function(player, result, msg)
        if player == LocalPlayer then
            teleportFailed = true
            print('[DIGSITE] ❌ TeleportInitFailed: ' .. tostring(result) .. ' | ' .. tostring(msg))
        end
    end)

    local ok, err = pcall(function()
        TPS:TeleportToPlaceInstance(game.PlaceId, picked.id, LocalPlayer)
    end)

    if not ok then
        conn:Disconnect()
        print('[DIGSITE] ❌ Teleport failed: ' .. tostring(err))
        self.failedServers[picked.id] = true
        return false
    end

    print('[DIGSITE] ✓ Teleport initiated')

    -- Teleport thành công thì script bị kill ở đây. Còn chạy tiếp = teleport thất bại -> đánh dấu & thử server khác
    local t0 = os.clock()
    while os.clock() - t0 < HOP_TELEPORT_WAIT and not teleportFailed do
        task.wait(0.5)
    end
    conn:Disconnect()

    print('[DIGSITE] ⚠️ Vẫn ở server cũ sau teleport → đánh dấu fail, thử server khác')
    self.failedServers[picked.id] = true
    return false
end

-- Fallback: hop thủ công bằng Roblox API (khi chưa nạp hop_client.lua hoặc backend lỗi nhiều lần)
function Transition:hopManualFallback()
    local hopSuccess = false
    while not hopSuccess do
        hopSuccess = self:hopToRandomServer()
        if not hopSuccess then
            print('[DIGSITE] Manual hop failed, retrying in 5 seconds...')
            task.wait(5)
        end
    end
end

-- Backend lỗi (pool rỗng / mất mạng) liên tiếp N lần thì chuyển sang hop thủ công
local BACKEND_HOP_MAX_FAILS = 3
-- Teleport do backend yêu cầu mà không có lỗi lẫn không thành công quá N lần thì chuyển sang hop thủ công
local BACKEND_HOP_MAX_SILENT = 8

local function hopUntilSuccess()
    print('[DIGSITE] → Farm signaled HOP, initiating server hop...')
    State.farmState = "STOPPING"

    local backendFails, silentFails = 0, 0

    while true do
        local hopFn = getgenv().TrackStatHop

        if not hopFn then
            print('[DIGSITE] ⚠️ hop_client.lua chưa nạp → hop thủ công')
            Transition:hopManualFallback()
            break
        end
        if backendFails >= BACKEND_HOP_MAX_FAILS or silentFails >= BACKEND_HOP_MAX_SILENT then
            -- Chỉ thử hop thủ công ĐÚNG 1 lần rồi quay lại backend: API Roblox hay trả 429 khi nhiều acc cùng gọi,
            -- còn pool của backend được cache nên đáng tin hơn
            print('[DIGSITE] ⚠️ Backend chưa xin được server → thử hop thủ công 1 lần')
            Transition:hopToRandomServer()
            backendFails, silentFails = 0, 0
            task.wait(5)
            continue
        end

        -- TrackStatHop() trả true khi đã reserve được server và gọi teleport, false khi pool rỗng / lỗi
        local ok, requested = pcall(hopFn)
        if not ok or not requested then
            backendFails = backendFails + 1
            print(string.format('[DIGSITE] ⚠️ Backend hop chưa xin được server (%d/%d): %s',
                backendFails, BACKEND_HOP_MAX_FAILS, tostring(ok and "pool rỗng/lỗi" or requested)))
            task.wait(5)
        else
            backendFails = 0
            -- Chờ teleport: thành công thì script bị kill ở đây. Server full / lỗi -> hop_client báo TELEPORT_FAILED
            local t0 = os.clock()
            local failed = false
            while os.clock() - t0 < HOP_TELEPORT_WAIT do
                task.wait(0.5)
                local statsFn = getgenv().TrackStatHopStats
                local stats = statsFn and statsFn() or nil
                local act = stats and tostring(stats.action) or ""
                if act:find("TELEPORT_FAILED", 1, true) or act:find("TELEPORT_ERROR", 1, true) then
                    failed = true
                    print('[DIGSITE] ⚠️ Teleport lỗi (' .. act .. ') → đợi 3s rồi xin server khác')
                    break
                end
            end

            if failed then
                task.wait(3)
            else
                silentFails = silentFails + 1
                print(string.format('[DIGSITE] ⚠️ Vẫn ở server cũ sau %ds (%d/%d) → xin server khác',
                    HOP_TELEPORT_WAIT, silentFails, BACKEND_HOP_MAX_SILENT))
            end
        end
    end

    State.farmState = "IDLE"
    print('[DIGSITE] Hopped successfully. Restart script to continue farming.')
end

-- =========== FPS BOOST ===========
local function boostFPS()
    pcall(function() setfpscap(FPS_CAP) end)
    print('[DIGSITE] ✓ FPS cap set to ' .. tostring(FPS_CAP))
end

local BOOST = {
    LOWMAP = true,
    DISABLE_3D = true,
}

local function applyLowMap()
    local w, l = game.Workspace, game:GetService("Lighting")
    local t = w.Terrain

    pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = 0 end)
    pcall(function() sethiddenproperty(l, "Technology", 2) end)
    pcall(function() sethiddenproperty(t, "Decoration", false) end)
    pcall(function()
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 1
        l.GlobalShadows = false
        l.FogEnd = 9e9
        l.Brightness = 0
        settings().Rendering.QualityLevel = "Level01"
    end)

    local function lowOne(v)
        if v:IsA("MeshPart") then
            v.Material = Enum.Material.Plastic
            v.Transparency = 1
            v.Reflectance = 0
            v.TextureID = ""
        elseif v:IsA("BasePart") then
            v.Material = Enum.Material.Plastic
            v.Transparency = 1
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        end
    end

    for _, v in ipairs(w:GetDescendants()) do pcall(lowOne, v) end
    for _, e in ipairs(l:GetChildren()) do
        if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
            pcall(function() e.Enabled = false end)
        end
    end
    w.DescendantAdded:Connect(function(v) pcall(lowOne, v) end)
end

function boostDigsiteFPS()
    local zone = getZoneObject("AdvancedDigsite")
    if not zone then
        if not State.digsiteBoosted then
            print('[DIGSITE] ⚠️ BoostFPS: AdvancedDigsite chưa load, bỏ qua')
        end
        return
    end
    if State.digsiteBoosted then
        -- Rejoin: zone mới sinh lại -> chỉ cần ẩn Ground lại (lowmap/3D render đã bật từ trước)
        pcall(function()
            for _, v in ipairs(zone:GetChildren()) do
                if v:IsA("Part") and v.Name == "Ground" then v.Transparency = 1 end
            end
        end)
        return
    end
    State.digsiteBoosted = true
    task.wait(2)

    pcall(function()
        -- ⚠️ KHÔNG xóa Important và các child của nó (ActiveBlocks, ActiveChests, TunnelTop)
        -- ClientModule cần những đối tượng này để hoạt động

        for _, v in ipairs(zone:GetChildren()) do
            if v:IsA("Part") and v.Name == "Ground" then v.Transparency = 1 end
        end
        -- Tạm dừng Map:ClearAllChildren() để tránh phá cấu trúc map
        -- local map = zone:FindFirstChild("Map")
        -- if map then map:ClearAllChildren() end
    end)

    pcall(function()
        local gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        for _, g in ipairs(gui:GetDescendants()) do
            if g.Name == "GoalsSide" then g:Destroy() end
        end
    end)

    task.wait(2)
    if BOOST.LOWMAP then
        local okLow, errLow = pcall(applyLowMap)
        print('[DIGSITE] Lowmap: ' .. (okLow and 'OK' or ('lỗi - ' .. tostring(errLow))))
    end
    task.wait(2)
    if BOOST.DISABLE_3D then
        pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(false) end)
    end
    print('[DIGSITE] ✓ BoostFPS Digsite applied')
end

-- =========== CLAIM FLIMSY SHOVEL ===========
-- Acc có Diamond nhưng chưa có Flimsy: phải vào Digsite thường và gửi "ClaimShovel" (giống claim-shovel.lua)
local CLAIM_SHOVEL_TRIES = 3
local CLAIM_SHOVEL_WAIT = 2

local function claimFlimsyShovel()
    if resolveActiveZone() ~= "Digsite" or not inspectZoneStructure("Digsite") then
        print('[CLAIM SHOVEL] Chưa ở Digsite → tele vào Digsite...')
        State.zonePhase = "DIGSITE"
        Transition:rejoinCurrent("claim_shovel")
        if resolveActiveZone() ~= "Digsite" then
            print('[CLAIM SHOVEL] ✗ Không vào được Digsite')
            return false
        end
    end

    for attempt = 1, CLAIM_SHOVEL_TRIES do
        local ok, err = pcall(function()
            getFireRemote():FireServer("Digsite", "ClaimShovel")
        end)
        print(string.format('[CLAIM SHOVEL] ClaimShovel gửi (%d/%d) | ok=%s %s',
            attempt, CLAIM_SHOVEL_TRIES, tostring(ok), ok and '' or tostring(err)))

        task.wait(CLAIM_SHOVEL_WAIT)
        State:update(true)   -- check lại inventory

        if State:ownsShovel("Flimsy Shovel") then
            print('[CLAIM SHOVEL] ✓ Flimsy Shovel đã có trong inventory')
            return true
        end
    end

    print('[CLAIM SHOVEL] ✗ Claim xong nhưng inventory vẫn chưa có Flimsy')
    return false
end

-- =========== WORLD 1 CHECK ===========
-- Nhận diện world bằng game.PlaceId (mỗi world là 1 place riêng: bắn World1Teleport xong script bị nạp lại).
-- (Lưu ý: isMainWorld()/leaveInstance() ở trên là "overworld vs instance TRONG 1 world", KHÔNG phân biệt World 1 với World 4.)
-- PlaceId World 1 lấy theo thứ tự: hằng số WORLD1_PLACE_ID -> file tự học (chỉ học khi đang đứng trong zone Digsite).
local WORLD1_PLACE_ID = 8737899170                -- place gốc "Pet Simulator 99!" (World 1). Chưa xác minh bằng Worlds.lua -> đối chiếu với log "PlaceId hiện tại" của acc World 1. nil = dùng file tự học
local WORLD1_FILE = "digsite_world1_placeid.txt"
local WORLD1_TELEPORT_REMOTE = "World1Teleport"   -- remote đã thấy bắn được ở log (không cần arg)
local WORLD1_MAX_FIRES = 3                        -- bắn tối đa N lần, không được thì dừng có kiểm soát
local WORLD1_WAIT_AFTER_FIRE = 20                 -- sau mỗi lần bắn chờ N giây (teleport thành công thì script bị nạp lại)
local world1IdCache = nil

local function getWorld1PlaceId()
    if WORLD1_PLACE_ID then return WORLD1_PLACE_ID end
    if world1IdCache then return world1IdCache end
    if readfile and isfile then
        local okF, exists = pcall(isfile, WORLD1_FILE)
        if okF and exists then
            local okR, txt = pcall(readfile, WORLD1_FILE)
            local n = okR and tonumber(txt) or nil
            if n then
                world1IdCache = n
                return n
            end
        end
    end
    return nil
end

-- Chỉ học khi có bằng chứng dương: đang đứng trong zone Digsite/AdvancedDigsite
local function learnWorld1PlaceId()
    if getWorld1PlaceId() then return end
    if resolveActiveZone() == nil then return end
    world1IdCache = game.PlaceId
    if writefile then pcall(writefile, WORLD1_FILE, tostring(game.PlaceId)) end
    print('[WORLD1] ✓ Đã học PlaceId World 1 = ' .. tostring(game.PlaceId) .. ' (lưu ở ' .. WORLD1_FILE .. ')')
end

-- Trả về: true (đang ở World 1) / false (world khác) / nil (chưa biết PlaceId World 1)
local function isWorld1Now()
    -- Digsite/AdvancedDigsite chỉ có ở World 1 -> đang trong zone là bằng chứng chắc nhất, ưu tiên hơn PlaceId
    if resolveActiveZone() ~= nil then return true, "đang trong zone Digsite" end
    local id = getWorld1PlaceId()
    if not id then
        return nil, "chưa biết PlaceId World 1"
    end
    return game.PlaceId == id, string.format("PlaceId=%s | World1=%s", tostring(game.PlaceId), tostring(id))
end

-- Trả về true = cứ chạy tiếp; false = không về được World 1 (caller dừng có kiểm soát)
local function ensureWorld1()
    local ok, why = isWorld1Now()
    print('[WORLD1] PlaceId hiện tại = ' .. tostring(game.PlaceId) .. ' | ' .. tostring(why))
    if ok == true then
        print('[WORLD1] ✓ Đang ở World 1')
        return true
    end
    if ok == nil then
        warn('[WORLD1] ⚠️ Chưa biết PlaceId World 1 -> bỏ qua kiểm tra, chạy tiếp như cũ. Điền WORLD1_PLACE_ID (lấy từ log "PlaceId hiện tại" của 1 acc đang ở World 1) để bật tự tele.')
        return true
    end

    print('[WORLD1] ⚠️ Không ở World 1 → bắn ' .. WORLD1_TELEPORT_REMOTE)
    local net = RS:FindFirstChild("Network")
    local remote = net and net:FindFirstChild(WORLD1_TELEPORT_REMOTE)
    if not remote then
        print('[WORLD1] ❌ Không thấy remote ' .. WORLD1_TELEPORT_REMOTE)
        return false
    end

    for i = 1, WORLD1_MAX_FIRES do
        print(string.format('[WORLD1] Bắn %s (%d/%d), chờ tối đa %ds (tele thành công thì script sẽ được nạp lại)...', WORLD1_TELEPORT_REMOTE, i, WORLD1_MAX_FIRES, WORLD1_WAIT_AFTER_FIRE))
        task.spawn(function()
            local okR, r1, r2 = pcall(function()
                if remote:IsA("RemoteFunction") then return remote:InvokeServer() end
                remote:FireServer()
                return true
            end)
            print(string.format('[WORLD1] %s trả về: ok=%s | %s | %s', WORLD1_TELEPORT_REMOTE, tostring(okR), tostring(r1), tostring(r2)))
        end)
        task.wait(WORLD1_WAIT_AFTER_FIRE)
        -- còn chạy tới đây = chưa bị teleport
    end
    print('[WORLD1] ❌ Đã bắn ' .. WORLD1_MAX_FIRES .. ' lần mà vẫn chưa rời world này')
    return false
end

-- =========== MAIN ===========
local function waitForGameReady()
    print('[DIGSITE] Waiting for game to load...')

    repeat task.wait(0.5) until game:IsLoaded()
    print('[DIGSITE] ✓ Game loaded')

    local lp = game.Players.LocalPlayer
    repeat task.wait(0.5) until lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    print('[DIGSITE] ✓ Character loaded')

    for attempt = 1, 15 do
        local ok, save = withIdentity(2, function()
            return require(game:GetService("ReplicatedStorage").Library.Client.Save).Get()
        end)

        if ok and save and save.Inventory then
            print('[DIGSITE] ✓ Inventory loaded')
            return true
        end

        print(string.format('[DIGSITE] ⏳ Inventory loading... (%d/15)', attempt))
        task.wait(0.5)
    end

    print('[DIGSITE] ⚠️ Inventory load timeout')
    return false
end

local function main()
    if State.farmState == "FARMING" then
        print('[DIGSITE] ⚠️ Farm already running, skipping')
        return
    end

    State.farmState = "FARMING"

    if not waitForGameReady() then
        print('[DIGSITE] ❌ Failed to load game/inventory, aborting')
        State.farmState = "IDLE"
        return
    end

    -- Việc đầu tiên: đảm bảo đang ở World 1 (Digsite chỉ có ở World 1)
    if not ensureWorld1() then
        print('[DIGSITE] ❌ Không về được World 1 → dừng có kiểm soát (không chạy farm sai world)')
        State.farmState = "IDLE"
        return
    end
    do
        local lpW = game.Players.LocalPlayer
        repeat task.wait(0.5) until lpW.Character and lpW.Character:FindFirstChild("HumanoidRootPart")
    end

    -- Claim mail trước khi farm
    print('[DIGSITE] Claiming mail...')
    for attempt = 1, 5 do
        if claimAllMail() then break end
        task.wait(2)
    end
    task.wait(1)

    State:update()

    -- Xác định quyền vào Advanced dựa trên inventory hiện tại
    local hasAdvancedAccess =
        State:ownsShovel("Pro Shovel")
        or State:ownsShovel("Platinum Shovel")
        or State:ownsShovel("Emerald Shovel")
        or State:ownsShovel("Sapphire Shovel")
        or State:ownsShovel("Amethyst Shovel")
        or (
            State:ownsShovel("Diamond Shovel")
            and State:ownsShovel("Flimsy Shovel")
        )

    if hasAdvancedAccess then
        State.zonePhase = "ADVANCED"
        print(string.format(
            '[DIGSITE] ✓ Advanced access detected | Best shovel: %s → vào Advanced',
            tostring(State.shovel)
        ))
    else
        State.zonePhase = "DIGSITE"
        print('[DIGSITE] No Advanced access → vào Digsite thường')
    end

    if State.zonePhase == "ADVANCED" then
        print('[DIGSITE] Already have Pro+, joining Advanced...')
        if not Transition:enterAdvancedAndSync("startup_pro+") then
            print('[DIGSITE] ❌ Failed to enter Advanced on startup')
            State.farmState = "IDLE"
            return
        end
        task.spawn(boostFPS)
        task.spawn(boostDigsiteFPS)
    else
        print('[DIGSITE] Joining normal Digsite...')
        local enterTeleport = game:GetService("Workspace").__THINGS.Instances.Digsite.Teleports:FindFirstChild("Enter")
        if enterTeleport then
            game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").CFrame = enterTeleport.CFrame
            task.wait(2)
        end
        task.spawn(boostFPS)

        print('[DIGSITE] Waiting for Digsite zone to load...')
        if waitForZoneReady("Digsite", 20) then
            print('[DIGSITE] ✓ Digsite zone loaded')
            dumpZone("Digsite")
            local gotBlocks = waitForZoneReady("Digsite", 20, true)
            print('[DIGSITE] ActiveBlocks có block: ' .. tostring(gotBlocks))
        else
            print('[DIGSITE] ⚠️ Zone load timeout')
        end
        State:update(true)
        State:resetStuck()
    end

    while State.farmState == "FARMING" do
        State:update()
        State:log()

        local activeZone = resolveActiveZone()

        -- Kiểm tra cấu trúc của zone hiện tại
        -- Áp dụng cho cả Digsite thường và AdvancedDigsite

        local expectedZone = State.zonePhase == "ADVANCED"
            and "AdvancedDigsite"
            or "Digsite"

        local structureOK, structureIssue = inspectZoneStructure(expectedZone)

        local zoneOK = activeZone == expectedZone and structureOK

        if not zoneOK then
            State.zoneBadSince = State.zoneBadSince or os.clock()

            local elapsed = os.clock() - State.zoneBadSince

            if elapsed >= ZONE_LOST_SECONDS then
                local reason

                if activeZone ~= expectedZone then
                    reason = "wrong_or_missing_zone:" .. tostring(activeZone)
                else
                    reason = structureIssue
                end

                print(string.format(
                    "[DIGSITE] ⚠️ ZONE RESET DETECTED | Expected=%s | Active=%s | Issue=%s",
                    expectedZone,
                    tostring(activeZone),
                    tostring(reason)
                ))

                State.zoneBadSince = nil

                -- Zone mất mà không còn ở World 1 thì về World 1 trước rồi mới recover
                if isWorld1Now() == false then
                    print('[DIGSITE] ⚠️ Không còn ở World 1 → về World 1 trước khi recover')
                    if not ensureWorld1() then
                        State.farmState = "IDLE"
                        break
                    end
                end

                local recovered = Transition:recoverCurrentPhase(reason)

                if not recovered then
                    print("[DIGSITE] ⚠️ Recovery failed, will retry zone validation")
                    task.wait(3)
                end
            else
                task.wait(0.25)
            end

            continue
        end

        State.zoneBadSince = nil
        learnWorld1PlaceId()   -- zone hợp lệ = đang ở World 1 -> nhớ PlaceId (chỉ ghi file 1 lần)

        task.spawn(autoCraftHugePotion)

        if State.zonePhase == "DIGSITE" then
            if State.shovel == "Pro Shovel" then
                print('[DIGSITE] ✓ Pro Shovel acquired!')
                if not Transition:enterAdvancedAndSync("bought_pro") then
                    task.wait(5)
                    continue
                end
                task.spawn(boostFPS)
                task.spawn(boostDigsiteFPS)
                continue
            end

            -- [NEW] Có Diamond thì cần CẢ Flimsy mới vào được Advanced.
            -- Chưa có Flimsy → vào Digsite claim → check lại inventory → đủ cả hai thì sang ADVANCED
            if State:ownsShovel("Diamond Shovel") then
                if not State:ownsShovel("Flimsy Shovel") then
                    print('[DIGSITE] Có Diamond nhưng chưa có Flimsy → vào Digsite claim Flimsy...')
                    claimFlimsyShovel()
                    State:update(true)
                end

                if State:ownsShovel("Diamond Shovel") and State:ownsShovel("Flimsy Shovel") then
                    print('[DIGSITE] ✓ Có cả Diamond + Flimsy → switching to Advanced phase')
                    State.zonePhase = "ADVANCED"
                    if not Transition:enterAdvancedAndSync("diamond_flimsy") then
                        task.wait(5)
                        continue
                    end
                    task.spawn(boostFPS)
                    task.spawn(boostDigsiteFPS)
                else
                    print('[DIGSITE] ⚠️ Chưa đủ Diamond + Flimsy, thử claim lại sau 5s')
                    task.wait(5)
                end
                continue
            end

            -- Nếu đã lấy Flimsy xong và có Diamond → chuyển sang ADVANCED luôn
            if State.shovel == "Flimsy Shovel" then
                local ok, save = withIdentity(2, function()
                    return require(game:GetService("ReplicatedStorage").Library.Client.Save).Get()
                end)
                local hasDiamond = false
                if ok and save and save.Inventory then
                    for catName, cat in pairs(save.Inventory) do
                        if type(cat) == "table" then
                            for _, item in pairs(cat) do
                                if type(item) == "table" and item.id == "Diamond Shovel" then
                                    hasDiamond = true
                                    break
                                end
                            end
                        end
                    end
                end
                if hasDiamond then
                    print('[DIGSITE] ✓ Flimsy claimed & Diamond detected → switching to Advanced phase')
                    State.zonePhase = "ADVANCED"
                    if not Transition:enterAdvancedAndSync("diamond_skip") then
                        task.wait(5)
                        continue
                    end
                    task.spawn(boostFPS)
                    task.spawn(boostDigsiteFPS)
                    continue
                end
            end

            local next = State:getNextShovel()
            if next and State.coins >= next.price then
                Purchase:buy(next.name)
                State:resetStuck()
            else
                if State:checkStuck() then
                    Transition:rejoinCurrent("stuck")   -- [FIX] rejoin Digsite thường, không đẩy sang Advanced
                    task.wait(2)
                else
                    farmStep()
                    if Farm.phase == "HOP" then
                        hopUntilSuccess()
                        break
                    end
                end
            end

        elseif State.zonePhase == "ADVANCED" then
            local hasAllAdvanced = State:ownsShovel("Amethyst Shovel") and State:ownsShovel("Sapphire Shovel") and State:ownsShovel("Emerald Shovel") and State:ownsShovel("Platinum Shovel")
            local hasDiamond = State:ownsShovel("Diamond Shovel")

            -- Bước gửi Diamond (acc nhận thì bỏ qua). Sau đó LUÔN đi tiếp flow chung bên dưới (mua/stuck-check/farm/HOP)
            if hasAllAdvanced and hasDiamond and not IS_DIAMOND_RECEIVER then
                local okD, dUid = pcall(findDiamondShovel)
                if okD and dUid and os.clock() - lastDiamondSendAttempt >= DIAMOND_SEND_COOLDOWN then
                    print('[DIGSITE] ✓ All 4 Advanced Shovels + Diamond detected, sending Diamond to ' .. DIAMOND_RECEIVER .. '...')
                    sendDiamondToReceiver()
                    State:update(true)
                    task.wait(2)
                end
            end

            do
                local next = State:getNextShovel()
                if next and State.coins >= next.price then
                    Purchase:buy(next.name)
                    State:resetStuck()
                else
                    if State:checkStuck() then
                        if Transition:rejoinAdvanced("stuck_advanced") then
                            State.rejoinAdvancedFails = 0
                        else
                            State.rejoinAdvancedFails = (State.rejoinAdvancedFails or 0) + 1
                            print(string.format('[DIGSITE] ❌ Rejoin Advanced thất bại (%d/%d)', State.rejoinAdvancedFails, REJOIN_SERVER_AFTER_FAILS))
                            if State.rejoinAdvancedFails >= REJOIN_SERVER_AFTER_FAILS then
                                State.rejoinAdvancedFails = 0
                                print('[DIGSITE] ❌ Rejoin Advanced nhiều lần vẫn lỗi → vào lại CÙNG server')
                                pcall(function()
                                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
                                end)
                                task.wait(15)
                            end
                        end
                        task.wait(2)
                    else
                        farmStep()
                        if Farm.phase == "HOP" then
                            hopUntilSuccess()
                            break
                        end
                    end
                end
            end
        end

        task.wait()   -- 1 frame (trước đây 50ms)
    end

    State.farmState = "IDLE"
    print('[DIGSITE] Main loop ended.')
end

main()
