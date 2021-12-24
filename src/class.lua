local module = {};

-- local exportItemMeta = {
-- 	__index = function (self,key)
-- 		local methods = self.__methods;
-- 		local events = self.__events;
-- 		return (methods and methods[key]) or (events and events[key]) or (self.getters[key](self.__this));
-- 	end;
-- 	__newindex = function (self,key,value)
-- 		self.__setters[key](self.__this,value);
-- 	end;
-- };

function module.init(shared)
	local new = {};
	local bind = shared.event.bind;
	local addObject = shared.store.addObject;
	local storeNew = shared.store.new;
	local mount = shared.mount;
	local getHolder = shared.mount.getHolder;

	-- make object that from instance, class and more
	function new.make(ClassName,...) -- render object
		-- make thing
		local item;
		local classOfClassName = type(ClassName);
		if classOfClassName == "string" then -- if classname is a string value, cdall instance.new for making new roblox instance
			item = Instance.new(ClassName);
		elseif classOfClassName == "function" then -- if classname is a function value, call it for making new object (OOP object)
			item = ClassName();
		elseif classOfClassName == "table" then -- if classname is a calss what is included new function, call it for making new object (object)
			local func = ClassName.new or ClassName.New or ClassName.__new;
			if ClassName.__noSetup then -- if is support initing props
				local childs,props = {},{...};
				local parsed;
				for iprop = #props,1,-1 do
					local prop = props[iprop];
					for i,v in ipairs(prop) do
						childs[i] = ((iprop == 1) and v or v:Clone());
						prop[i] = nil;
					end
					if next(prop) then -- there are (key/value)s
						if parsed then
							for i,v in pairs(prop) do
								parsed[i] = v;
							end
						else
							parsed = prop;
						end
					end
				end
				item = func(parsed);
				local holder = getHolder(item);
				for _,v in ipairs(childs) do
					mount(item,v,holder);
				end
				return item;
			end
			item = func();
		end
		if not item then -- if cannot make new object, ignore this call
			local str = tostring(ClassName);
			print(("fail to make item '%s', did you forget to checking the class '%s' is exist?"):format(str,str));
		end

		-- set property and adding child and binding functions
		local holder = getHolder(item); -- to __holder or holder or it self (for tabled)
		-- for iprop,prop in ipairs({...}) do
		for iprop = select("#",...),1,-1 do
			local prop = select(iprop,...);
			for index,value in pairs(prop) do
				local valueType = typeof(value);
				local indexType = typeof(index);

				-- child
				if indexType == "string" and valueType == "table" and value.t == "reg" then -- register (bind to store event)
					-- store binding
					local with = value.wfunc;
					local set = value.store[value.key];
					if set then
						if with then
							set = with(set);
						end
						item[index] = set;
					else
						local dset = value.dvalue;
						if dset then
							item[index] = dset;
						end
					end
					local tween = value.tvalue;

					-- adding event function
					local function regFn(newValue,store)
						if with then
							newValue = with(newValue,item,store);
						end
						item[index] = newValue;
					end
					value.register(regFn);

					-- this is using hacky of roblox instance
					-- this is will keep reference from week table until
					-- inscance got GCed
					item:GetPropertyChangedSignal("ClassName"):Connect(regFn);
				elseif (valueType == "function" or valueType == "table") and bind(item,index,value,valueType) then -- connect event
					-- event binding
				elseif indexType == "string" then
					-- prop set
					item[index] = value; -- set property
				elseif indexType == "number" then -- object
					-- child object
					mount(item,((iprop == 1) and value or value:Clone()),holder);
				end
			end
		end
		return item;
	end
	local make = new.make;

	-- import quad object
	function new.import(ClassName,defaultProperties) -- make new quad class object
		local this = defaultProperties or {};
		setmetatable(this,{
			__call = function (self,prop)
				if type(prop) == "string" then
					local lastName = prop;
					return function (nprop)
						nprop.Name = lastName;
						local item = make(ClassName,nprop);
						addObject(lastName,item);
						return item;
					end;
				end
				return make(ClassName,prop,this);
			end;
		});
		return this;
	end

	-- function new.export(newFn,setters,getters,methods,events) -- make quad importable class
	-- 	return function ()
	-- 		return setmetatable({
	-- 			__this = newFn();
	-- 			__setters = setters;
	-- 			__getters = getters;
	-- 			__methods = methods;
	-- 			__events = events;
	-- 		},exportItemMeta);
	-- 	end;
	-- end

	-- set module calling function
	setmetatable(new,{
		__call = function (self,...)
			return new.import(...);
		end;
	});

	-- make class
	function new.extend()
		local this = {};

		--- make new object
		function this.new(prop)
			-- make metatable
			prop = storeNew(prop);
			local parent = prop and (prop.Parent or prop.parent);
			local self = {__prop = prop; __parent = parent};
			local init = this.init;
			if init then
				init(self,prop);
			end
			setmetatable(self,this);

			-- render that
			local object = self:render(prop);
			rawset(self,"__object",object);
			rawset(self,"__holder",object);
			if parent then
				rawset(self,"__parent",parent);
				mount(item,parent)
			end
			-- prevent gc
			((type(object) == "table" and object.__object) or object):GetPropertyChamgedSignal "ClassName":Connect(function()
				return item;
			end);
			return self;
		end

		--- re-render object (if some props chaged, call this to render again)
		function this:update() -- swap object
			local object = rawget(self,"__object"); -- get last instance
			local parent = object and object.Parent; -- date parent
			if not object then
				parent = rawget(self,"__parent");
			end
			local lastObject = object;
			if lastObject then
				lastObject.Parent = nil;
			end
			object = self:render(self.__prop); -- new instance
			rawset(self,"__holder",object);
			rawset(self,"__object",object);
			object.Parent = getHolder(parent); -- update parent
			-- restore childs
			local child = rawget(self,"__child");
			if child then
				for _,v in pairs(child) do
					if v then
						((type(v) == table and rawget(v,"__object") or v).Parent = object;
					end
				end
			end
			-- prevnet gc
			((type(object) == "table" and object.__object) or object):GetPropertyChamgedSignal "ClassName":Connect(function()
				return item;
			end);
			if lastObject then -- remove old instance
				self:Destroy(lastObject);
			end
		end

		-- define destroy method
		function this:Destroy(object)
			local unload = rawget(self,"unload");
			object = object or rawget(self,"__object");
			if object then
				if unload then
					unload(self,object);
				else
					local destroy = (object.Destroy or object.destroy);
					if destroy then
						pcall(destroy,object);
					end
				end
			end
			self = nil;
		end

		--- link to new
		function this.__call(self,...)
			return (self.new or self.New or self.__new)(...);
		end;

		-- indexer (getter)
		function this:__index(k)
			if k == "destroy" then
				return self.Destroy;
			end
			local getter = this.getter[k];
			if getter then
				return getter(self,rawget(self,"__object"));
			end

			-- from this (have more priority)
			local fromThis = this[k];
			if fromThis then
				return fromThis;
			end

			-- from prop, not start with '_' (private value)
			if k:sub(1,1) ~= "_" then
				return self.__prop[k];
			end
		end

		--- new indexer (setter)
		function this:__newindex(k,v)
			-- from setter
			local setter = this.setter[k];
			if setter then
				return setter(self,v,rawget(self,"__object"));
			end

			-- is private (self value)
			if k == "holder" or k:sub(1,1) == "_" then
				return rawset(self,k,v);
			end

			-- prop update
			self.__prop[k] = v;
			if this.updateTriggers[k] then
				self:update();
			end
		end

		this.getter = {};
		this.setter = {
			Parent = function(self,parent,object)
				rawset(self,"__parent",parent);
				if object then
					object.Parent = getHolder(parent);
				end
			end;
		};
		this.updateTriggers = {};
		this.__noSetup = true;
		return this;
	end

	return new;
end

return module;
