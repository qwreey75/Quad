local module = {};

function module.init(shared)
    local new = {};
    local insert = table.insert;

    local mountClass = {};
    mountClass.__index = mountClass;
    function mountClass:unmount()
        local this = self.this
        local typeThis = type(this);
        if typeThis == "userdata" then
            this:Destroy();
        elseif typeThis == "table" then
            pcall(function()
                this.Parent = nil;
            end);
            local destroyThis = this.Destroy;
            if destroyThis then
                pcall(destroyThis,this);
            end
            --if sef.to when
            -- todo for remove child on parent
        end
    end

    function new.getHolder(item)
		return (type(item) == "table") and (item._holder or item.holder or item.__holder) or item;
	end
	local getHolder = new.getHolder;

    -- we should add plugin support
    function new.mount(to,this,holder)
        local thisObject = this;
        if type(this) == "table" then
            thisObject = this.__object;
            local parent = rawget(this,"__parent");
            if type(parent) == "table" then
                local parentChild = rawget(parent,"__child");
                if parentChild then
                    for i,v in pairs(parentChild) do
                        if v == this then
                            parentChild[i] = nil;
                        end
                    end
                end
            end
            rawset(this,"__parent",to);
        end
        if thisObject then
            thisObject.Parent = holder or getHolder(to);
        end
        if type(to) == "table" then
            local child = rawget(to,"__child");
            if not child then
                child = {};
                rawset(to,"__child",child);
            end
            insert(child,this);
        end
        return setmetatable({to = to,this = this},mountClass);
    end
    local mount = new.mount;

    local pack = table.pack;
    local mountsClass = {};
    mountsClass.__index = mountsClass;
    function mountsClass:unmount()
        for _,v in ipairs(self) do
            v:unmount();
        end
    end
    setmetatable(new,{
        __call = function (self,to,...)
            if select("#",...) == 1 then
                return new.mount(to,...);
            end
            local mounts = {};
            local items = pack(...);
            for _,item in ipairs(items) do
                insert(mounts,mount(to,item));
            end
            setmetatable(mounts,mountsClass);
            return mounts;
        end;
    });

    return new;
end

return module;
