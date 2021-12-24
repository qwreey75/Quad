local module = {};

--[[
this feature allows get object without making some created callback and local var
but, it can't allows mulit id and object
this feature should be upgraded
]]
local wrap = coroutine.wrap;
local insert = table.insert;
local remove = table.remove;

local function catch(...)
	local passed,err = pcall(...);
	if not passed then
		warn ("[QUAD] Error occured while operating async task\n" .. tostring(err));
	end
end

local week = {__mode = "vk"};
function module.init(shared)
	local new = {};
	local items = shared.items;

	-- id space (array of object)
	local objSpace = {};
	function objSpace:each(func)
		for i,v in ipairs(self) do
			wrap(catch)(func,i,v);
		end
	end
	function objSpace:eachSync(func)
		for i,v in ipairs(self) do
			local ret = func(i,v);
			if ret then
				break;
			end
		end
	end
	function objSpace:remove(indexOrItem)
		local thisType = type(indexOrItem);
		if thisType == "number" then
			remove(self,indexOrItem);
		else
			for i,v in pairs(self) do
				if v == indexOrItem then
					remove(self,i);
					break;
				end
			end
		end
	end
	function objSpace.__new()
		return setmetatable({},objSpace);
	end
	function objSpace:__newIndex(key,value) -- props setter
		self:each(function (this)
			this[key] = value;
		end);
	end
	objSpace.__mode = "kv"; -- week link for gc
	objSpace.__index = objSpace;

	-- get object array with id (objSpace)
	function new.getObjects(id)
		return items[id];
	end
	-- get first object with id (not array)
	function new.getObject(id)
		local item = items[id];
		return item and item[1];
	end
	--TODO: if item is exist already, ignore this call
	-- adding object with id
	function new.addObject(ids,object)
		for id in ids:gmatch("[^,]+") do -- split by ,
			-- remove trailing, heading spaces
			id = id:gsub("^ +",""):gsub(" +$","");
			local array = items[id];
			if not array then
				array = objSpace.__new();
				items[id] = array;
			end
			insert(array, object);
		end
	end

	local registerMt = {
		register = function (s,efunc)
			insert(s.event,efunc);
		end;
		with = function (s,efunc)
			return setmetatable({wfunc = efunc},{__index = s});
		end;
		default = function (s,value)
			return setmetatable({dvalue = value},{__index = s});
		end;
		tween = function (s,value)
			return setmetatable({tvalue = value},{__index = s});
		end;
		from = function (s,value)
			return setmetatable({fvalue = value},{__index = s});
		end;
	};
	registerMt.__index = registerMt;

	-- bindable store object
	local store = {};
	local storeIdSpace = {};
	function store:__index(key)
		return self.__self[key] or store[key];
	end
	function store:__newindex(key,value)
		self.__self[key] = value;
		local event = self.__evt[key];
		if event then
			for _,v in pairs(event) do -- NO ipairs here
				wrap(catch)(v,value,store);
			end
		end
	end
	function store:__call(key,func)
		local register = self.__reg[key];
		if not register then
			local event = setmetatable({},week);
			self.__evt[key] = event;
			register = setmetatable({
				event = event;
				key = key;
				store = self;
				t = "reg";
			},registerMt);
			self.__reg[key] = register;
		end

		if func then
			register.register(func);
		end
		return register;
	end
	function store:default(key,value)
		self[key] = self[key] or value;
	end
	function new.new(self,id)
		if id then
			local old = storeIdSpace[id];
			if old then
				return old;
			end
		end
		local this = setmetatable(
			{__self = self or {},__evt = setmetatable({},week),__reg = setmetatable({},week)},store
		);
		if id then
			storeIdSpace[id] = this;
		end
		return this;
	end
	function new.getStore(id)
		return storeIdSpace[id] or new.new({},id);
	end

	return new;
end

return module;
