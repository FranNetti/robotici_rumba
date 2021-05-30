local extension = table

function extension.insertMultiple(_table, list)
    for i = 1, #list do
        table.insert(_table, list[i])
    end
end

function extension.split(_table, splitIndex)
    local t1, t2 = {}, {}
    for i = 1, #_table do
        if i < splitIndex then
            table.insert( t1, _table[i])
        else
            table.insert( t2, _table[i])
        end
    end
    return t1, t2
end

function extension.equals(t1, t2)
    if #t1 ~= #t2 then
        return false
    end
    for i = 1, #t1 do
        if t1[i] ~= t2[i] then
            return false
        end
    end
    return true
end

function extension.contains(_table, value)
    for i = 1, #_table do
        if _table[i] == value then
            return true
        end
    end
    return false
end

function extension.containsAny(_table, values)
    for i = 1, #_table do
        if extension.contains(values, _table[i]) then
            return true
        end
    end
    return false
end

function extension.containsTable(_table, value)
    for i = 1, #_table do
        if extension.equals(value, _table[i]) then
            return true
        end
    end
    return false
end

function extension.any(_table, fun)
    for i = 1, #_table do
        if fun(_table[i]) then
            return true
        end
    end
    return false
end

function extension.none(_table, fun)
    return not extension.any(_table, fun)
end

return extension