-- a short program to calculate the optimum allocations
-- of suffixes for attributes based on need

-- Data

local itemStats = {
    bow = {toDex = {min = 8, max = 55}},
    quiver = {toDex = {min = 8, max = 60}},

    helmet_gen = {toInt = {min = 8, max = 60}}, -- everybody gets int
    helmet_str = {toStr = {min = 8, max = 55}},
    helmet_dex = {toDex = {min = 8, max = 55}},
    helmet_int = {},
    helmet_str_dex = {{toStr = {min = 8, max = 55},
                        {toDex = {min = 8, max = 55}}}},
    helmet_str_int = {toStr = {min = 8, max = 55}},
    helmet_dex_int = {toDex = {min = 8, max = 55}},

    gloves_gen = {toDex = {min = 8, max = 60}}, -- everybody gets dex
    gloves_str = {toStr = {min = 8, max = 55}},
    gloves_dex = {},
    gloves_int = {toDex = {min = 8, max = 55}},
    gloves_str_dex = {toStr = {min = 8, max = 55}},
    gloves_str_int = {{toStr = {min = 8, max = 55}},
                     {toInt =  {min = 8, max = 55}}},
    gloves_dex_int = {toInt = {min = 8, max = 55}},

    boots_str = {toStr = {min = 8, max = 55}},
    boots_dex = {toDex = {min = 8, max = 55}},
    boots_int = {toInt = {min = 8, max = 55}},
    boots_str_dex = {toStr = {min = 8, max = 55}, 
                    {toDex = {min = 8, max = 55}}},
    boots_str_int = {toStr = {min = 8, max = 55}, 
                    {toInt = {min = 8, max = 55}}},
    boots_dex_int = {toDex = {min = 8, max = 55}, 
                    {toInt = {min = 8, max = 55}}},

    body_str = {toStr = {min = 8, max = 55}},
    body_dex = {toDex = {min = 8, max = 55}},
    body_int = {toInt = {min = 8, max = 55}},
    body_str_dex = {toStr = {min = 8, max = 55}, {toDex = {min = 8, max = 55}}},
    body_str_int = {toStr = {min = 8, max = 55}, {toInt = {min = 8, max = 55}}},
    body_dex_int = {toDex = {min = 8, max = 55}, {toInt = {min = 8, max = 55}}},
    body_str_dex_int = {toStr = {min = 8, max = 55}}, 
                        {toDex = {min = 8, max = 55}}, 
                        {toInt = {min = 8, max = 55}},

    belt_gen = {toStr = {min = 8, max = 60}}, -- everybody gets str
    belt_heavy = {toStr = {min = 25, max = 35}}, --implicit

    ring = {toStr = {min = 8, max = 55}},
            {toDex = {min = 8, max = 55}},
            {toInt = {min = 8, max = 55}},
            {toAll = {min = 1, max = 16}},
  
    amulet = {toStr = {min = 8, max = 55}},
            {toDex = {min = 8, max = 55}},
            {toInt = {min = 8, max = 55}},
            {toAll = {min = 1, max = 35}},
    
    amulet_amber = {toStr = {min = 20, max = 30}},
    amulet_jade = {toDex = {min = 20, max = 30}},
    amulet_lapis = {toInt = {min = 20, max = 30}},
    amulet_onyx = {toAll = {min = 10, max = 16}},
    amulet_turquoise = {toDex = {min = 16, max = 24}},
    amulet_agate = {toStr = {min = 16, max = 24}},
    amulet_citrine = {toStr = {min = 16, max = 24}},

-- Crafting
    craft_toStr = {toStr = {min = 15, max = 30}},
    craft_toStrDex = {toStrDex = {min = 10, max = 25}},
    craft_toStrInt = {toStrInt = {min = 10, max = 25}},
    craft_toDex = {toDex = {min = 15, max = 30}},
    craft_toDexInt = {toDexInt = {min = 10, max = 25}},
    craft_toInt = {toInt = {min = 15, max = 30}},
    craft_toAll = {toAll = {min = 6, max = 13}},

--Veiled
    craft_toStrDex = {toStrDex = {min = 31, max = 35}},
    craft_toStrInt = {toStrInt = {min = 31, max = 35}},
    craft_toDexInt = {toDexInt = {min = 31, max = 35}},

--Essence
    essence_toStr = {toStr = {min = 18, max = 58}},
    essence_toDex = {toDex = {min = 13, max = 58}},
    essence_toInt = {toInt = {min = 28, max = 58}},
    }

--From tree
local strengthFromTree = 24
local dexterityFromTree = 320 - 58
local intelligenceFromTree = 14

--Items to keep
local myItems = {
    myBow = {str=0,dex=10,int=0, avail = false},
    myQuiver = {str=0,dex=0,int=0, avail = true},
    myHelm = {str=0,dex=0,int=0, avail = false},
    myBody = {str=40,dex=0,int=0, avail = true},
    myGoves = {str=0,dex=0,int=22, avail = false},
    myBoots = {str=0,dex=30,int=0, avail = true},
    myAmulet = {str=41,dex=18,int=0, avail = false},
    myRing1 = {str=0,dex=0,int=34, avail = true},
    myRing2 = {str=0,dex=0,int=33, avail = true},
    myBelt = {str=54,dex=0,int=0, avail = true},
    myJewels = {str=0,dex=0,int=0, avail = true},
}
local strKeep = 0
local dexKeep = 0
local intKeep = 0

for k,v in pairs(myItems) do
    if not v.avail then
        -- print(v.int)
        strKeep = strKeep + v.str
        dexKeep = dexKeep + v.dex
        intKeep = intKeep + v.int
    end
end

print(strKeep,dexKeep, intKeep)
print(myItems.myBow.avail)

local strengthRequired = 180
local dexterityRequired = 185
local intelligenceRequired = 122

local sN = strengthRequired - strengthFromTree - strKeep --strengthNeeded
local dN = dexterityRequired - dexterityFromTree - dexKeep --dexterityNeeded
local iN = intelligenceRequired - intelligenceFromTree - intKeep --intelligenceNeeded

-- Functions

function setZero(sN,dN,iN) -- if requirement goes below zero, set to zero
    if sN < 0 then sN = 0 end
    if dN < 0 then dN = 0 end
    if iN < 0 then iN = 0 end
    print("setZero",sN,dN,iN)
    return sN,dN,iN
end

function checkCraft(sN,dN,iN) -- check if any stat in range for suffix craft
    if sN>10 and sN<25 or dN>10 and dN<25 or iN>10 and iN<25 then
        return true
    end
end

function checkCatalyst(sN,dN,iN) -- check if any stat in range for catalyst
    if sN>0 and sN<=10 or dN>0 and dN<=10 or iN>0 and iN<=10 then
        return true
    end
end

function setAmulet(sN,dN,iN) -- choose amulet based on attribute needs
    if sN>0 and dN>0 and iN>0 then
        print("onyx amulet for all 3 attributes")
        sN = sN - 13
        dN = dN  - 13
        iN = iN - 13
    elseif sN>0 and  dN>0 and iN<=0 then
        print("citrine amulet for strength and dexterity")
        sN = sN - 20
        dN = dN - 20
    elseif sN>0 and  dN<=0 and iN>0 then
        print("agate amulet for strength and intelligence")
        sN = sN - 20
        iN = iN - 20
    elseif sN<=0 and  dN>0 and iN>0 then
        print("turquoise amulet for dexterity and intelligence")
        iN = iN - 20
        dN = dN - 20
    elseif sN>0 and  dN<=0 and iN<=0 then
        print("amber amulet for only strength")
        sN = sN - 25
    elseif sN<=0 and  dN>0 and iN<=0 then
        print("jade amulet for only dexterity")
        dN = dN - 25
    elseif sN<=0 and  dN<=0 and iN>0 then
        print("lapis amulet for only intelligence")
        iN = iN - 25
    elseif sN<=0 and  dN<=0 and iN<=0 then
        print("any amulet, attributes are covered")
    end
    sN,dN,iN = setZero(sN,dN,iN)
    return sN,dN,iN
end

function setBelt(sN,dN,iN)
    if sN>0 then
        sN = sN - 30
        print("heavy belt for strength")
        sN,dN,iN = setZero(sN,dN,iN)
    end
    return sN,dN,iN
end

function setPrimeStats(sN,dN,iN)
    if sN > 25 and myItems.myBelt.avail then
        print("strength stat ~50 on belt")
        sN = sN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end
    if dN > 25 and myItems.myGoves.avail then
        print("dexterity stat ~50 on gloves")
        dN = dN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end   
    if iN > 25 and myItems.myHelm.avail then
        print("intelligence stat ~50 on helmet")
        iN = iN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end
    return sN,dN,iN
end

function setJewelryStats(sN,dN,iN)
    if sN > 25 then
        print("strength stat ~50 on amulet or ring")
        sN = sN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end
    if dN > 25 then
        print("dexterity stat ~50 on amulet or ring")
        dN = dN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end
    if iN > 25 then
        print("intelligence stat ~50 on amulet or ring")
        iN = iN - 50
        sN,dN,iN = setZero(sN,dN,iN)
    end
    return sN,dN,iN
end

--Logic
print("Start",sN,dN,iN)

sN,dN,iN = setZero(sN,dN,iN)

if myItems.myAmulet.avail then
    sN,dN,iN = setAmulet(sN,dN,iN)
end

if myItems.myBelt.avail then
    sN,dN,iN = setBelt(sN,dN,iN)
end

if (sN>25 and dN>25) or (sN>25 and iN>25) or (dN>25 and iN>25) then
    print("consider a veiled mod due to two requirements over 25")
end

sN,dN,iN = setPrimeStats(sN,dN,iN)

while (sN > 25 or dN>25 or iN>25) and (myItems.myRing1.avail or myItems.myRing2.avail or myItems.myAmulet.avail) do
    sN,dN,iN = setJewelryStats(sN,dN,iN)
end

while checkCraft(sN,dN,iN) do
    if sN >10 and dN>10 then
        print("craft a str-dex mod at open suffix")
        sN = sN - 25
        dN = dN - 25
    elseif sN >10 and iN > 10 then
        print("craft a str-int mod at open suffix")
        sN = sN - 25
        iN = iN - 25
    elseif dN>10 and iN>10 then
        print("craft a dex-int mod at open suffix")
        dN = dN - 25
        iN = iN - 25
    elseif sN>10 then
        print("craft a strength mod at open suffix")
        sN = sN - 30
    elseif dN>10 then
        print("craft a dex mod at open suffix")
        dN = dN - 30
    elseif iN>10 then
        print("craft an int mod at open suffix")
        iN = iN - 30
    end
    sN,dN,iN = setZero(sN,dN,iN)
end

if checkCatalyst(sN,dN,iN) then
    print("intrinsic catalysts to complete")
end
print(itemStats.essence_toDex.toDex.max)
