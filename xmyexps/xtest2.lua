showtable = function(table)
    print(table)
    for k,v in pairs(table) do
        print(k,v)
    end
end
print("1")
Animal = {}
AnimalPrototype = {legs=4, eyes=2, skin="fur", name=
"fluffy", }
Animal.name="spot"
function Animal.new(o)
  setmetatable(o, AnimalPrototype)
  return o
end
AnimalPrototype.__index = function (table, key)
    return AnimalPrototype[key]
  end
human = Animal.new({eyes=2})
print(human.name)    --> "spot"
showtable(Animal)
showtable(AnimalPrototype)
showtable(human)
humanmeta=getmetatable(human)
print(humanmeta)

