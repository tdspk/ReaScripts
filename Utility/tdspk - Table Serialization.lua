data = {
    name = "Karl",
    age = 23
}

function serialize(data)
    local serialized = "{"

    for k, v in pairs(data) do
        local key = type(k) == "string" and '"' .. k .. '"' or k
        local value = type(v) == "string" and '"' .. v .. '"' or v
        serialized = serialized .. "[" .. key .. "]=" .. value .. ","
    end

    serialized = serialized .. "}"
    return serialized
end

serdata = serialize(data)

deser_data = load("return " .. serdata)

table.to
