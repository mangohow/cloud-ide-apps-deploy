local function split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function (w)
        table.insert(resultStrList,w)
    end)
    return resultStrList
end


--[[
    1、解析出路径中的uid和其它路径
--]]

-- 获取请求的路径
local request_uri = ngx.var.request_uri
-- 分割路径
local data = split(request_uri, '/')

-- 请求路径为 /ws/uid/... , 因此至少为2个
if #data < 2 then
    return
end

-- lua中数组下标从1开始，uid为第二个
local ws = data[1]
if ws ~= "ws" then
    return ngx.exit(404)
end

local uid = data[2]
local uid_index = string.find(request_uri, uid)
local other_path_indx = uid_index + string.len(uid)
-- 获取到uid后面的路径
local other_path = string.sub(request_uri, other_path_indx + 1)

if other_path == '/' then
    other_path = ''
end

-- 设置nginx.conf中的变量
ngx.var.pth = other_path

--[[
    2、从redis中根据uid查询后端ip和端口
    注意：在跳转网页时 一定是 http://ip:port/ws/uid/    最后面一定要有'/'
--]]

-- 连接redis
local redis = require "resty.redis"
local red = redis:new()
red:set_timeouts(1000, 1000, 1000) -- 1 sec
local ok, err = red:connect("10.102.123.62", 6379)
if not ok then
    ngx.log(ngx.ERR, "failed to connect to redis")
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- 根据uid从redis中获取ip和port
local res, err = red:hget('hosts', uid)
if not res then
    ngx.log(ngx.ERR, "failed get host, uid:"..uid, err)
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

if res == ngx.null then
    ngx.log(ngx.ERR, 'failed get host, uid:'..uid)
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

ngx.log(ngx.INFO, 'uid:'..uid..', host:'..res)

-- 设置backend
ngx.var.backend = res
ngx.log(ngx.NOTICE, "other_path: "..other_path)


-- local ok, err = red:set_keepalive(10000, 100)
-- if not ok then
--     ngx.log(ngx.ERR, "failed to set keepalive: ", err)
--     return
-- end
-- ngx.var.backend = '127.0.0.1:8080'

-- ngx.log(ngx.ERR, data[2])
-- ngx.say(#data)
-- ngx.say(data[1].." "..data[2])
-- ngx.say(uid)
-- ngx.say(other_path)
