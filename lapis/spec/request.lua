local normalize_headers
do
  local normalize
  normalize = function(header)
    return header:lower():gsub("-", "_")
  end
  normalize_headers = function(t)
    return setmetatable((function()
      local _tbl_0 = { }
      for k, v in pairs(t) do
        _tbl_0[normalize(k)] = v
      end
      return _tbl_0
    end)(), {
      __index = function(self, name)
        return rawget(self, normalize(name))
      end
    })
  end
end
local mock_request
mock_request = function(app, url, opts)
  if opts == nil then
    opts = { }
  end
  local stack = require("lapis.spec.stack")
  local parse_query_string, encode_query_string
  do
    local _obj_0 = require("lapis.util")
    parse_query_string, encode_query_string = _obj_0.parse_query_string, _obj_0.encode_query_string
  end
  local insert, concat
  do
    local _obj_0 = table
    insert, concat = _obj_0.insert, _obj_0.concat
  end
  local logger = require("lapis.logging")
  local old_logger = logger.request
  logger.request = function() end
  local url_base, url_query = url:match("^(.-)%?(.*)$")
  if not (url_base) then
    url_base = url
  end
  local get_params
  if url_query then
    get_params = parse_query_string(url_query)
  else
    get_params = { }
  end
  if opts.get then
    for k, v in pairs(opts.get) do
      if type(k) == "number" then
        insert(get_params, v)
      else
        get_params[k] = v
      end
    end
  end
  for k, v in pairs(get_params) do
    if type(v) == "table" then
      get_params[v[1]] = nil
    end
  end
  url_query = encode_query_string(get_params)
  local request_uri = url_base
  if url_query == "" then
    url_query = nil
  else
    request_uri = request_uri .. ("?" .. url_query)
  end
  local host = opts.host or "localhost"
  local request_method = opts.method or "GET"
  local scheme = opts.scheme or "http"
  local server_port = opts.port or 80
  local http_host = host
  if not (server_port == 80) then
    http_host = http_host .. ":" .. tostring(server_port)
  end
  local prev_request = normalize_headers(opts.prev or { })
  local headers = {
    Host = host,
    Cookie = prev_request.set_cookie
  }
  if opts.headers then
    for k, v in pairs(opts.headers) do
      headers[k] = v
    end
  end
  headers = normalize_headers(headers)
  local out_headers = { }
  local old_ngx = ngx
  local nginx = require("lapis.nginx")
  local buffer = { }
  local flatten
  flatten = function(tbl, accum)
    if accum == nil then
      accum = { }
    end
    for _index_0 = 1, #tbl do
      local thing = tbl[_index_0]
      if type(thing) == "table" then
        flatten(thing, accum)
      else
        insert(accum, thing)
      end
    end
    return accum
  end
  stack.push({
    print = function(...)
      local args = flatten({
        ...
      })
      local str
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #args do
          local a = args[_index_0]
          _accum_0[_len_0] = tostring(a)
          _len_0 = _len_0 + 1
        end
        str = _accum_0
      end
      for _index_0 = 1, #args do
        local a = args[_index_0]
        insert(buffer, a)
      end
      return true
    end,
    say = function(...)
      ngx.print(...)
      return ngx.print("\n")
    end,
    header = out_headers,
    var = setmetatable({
      host = host,
      http_host = http_host,
      request_method = request_method,
      request_uri = request_uri,
      scheme = scheme,
      server_port = server_port,
      args = url_query,
      query_string = url_query,
      uri = url_base
    }, {
      __index = function(self, name)
        do
          local header_name = name:match("^http_(.+)")
          if header_name then
            return headers[header_name]
          end
        end
      end
    }),
    req = {
      read_body = function() end,
      get_headers = function()
        return headers
      end,
      get_uri_args = function()
        local out = { }
        local add_arg
        add_arg = function(k, v)
          do
            local current = out[k]
            if current then
              if type(current) == "table" then
                return insert(current, v)
              else
                out[k] = {
                  current,
                  v
                }
              end
            else
              out[k] = v
            end
          end
        end
        for k, v in pairs(get_params) do
          if type(v) == "table" then
            add_arg(unpack(v))
          else
            add_arg(k, v)
          end
        end
        return out
      end,
      get_post_args = function()
        return opts.post or { }
      end
    }
  })
  local response = nginx.dispatch(app)
  stack.pop()
  logger.request = old_logger
  return response.status or 200, concat(buffer), out_headers
end
local assert_request
assert_request = function(...)
  local res = {
    mock_request(...)
  }
  if res[1] == 500 then
    assert(false, "Request failed: " .. res[2])
  end
  return unpack(res)
end
local mock_action
mock_action = function(url, opts, fn)
  local Application
  do
    local _obj_0 = require("lapis.application")
    Application = _obj_0.Application
  end
  local ret
  local A
  do
    local _parent_0 = Application
    local _base_0 = {
      ["/*"] = function(...)
        ret = {
          fn(...)
        }
        return nil
      end
    }
    _base_0.__index = _base_0
    setmetatable(_base_0, _parent_0.__base)
    local _class_0 = setmetatable({
      __init = function(self, ...)
        return _parent_0.__init(self, ...)
      end,
      __base = _base_0,
      __name = "A",
      __parent = _parent_0
    }, {
      __index = function(cls, name)
        local val = rawget(_base_0, name)
        if val == nil then
          return _parent_0[name]
        else
          return val
        end
      end,
      __call = function(cls, ...)
        local _self_0 = setmetatable({}, _base_0)
        cls.__init(_self_0, ...)
        return _self_0
      end
    })
    _base_0.__class = _class_0
    if _parent_0.__inherited then
      _parent_0.__inherited(_parent_0, _class_0)
    end
    A = _class_0
  end
  assert_request(A(), url, opts)
  return unpack(ret)
end
local server_loaded = 0
local server_port = nil
local load_test_server
load_test_server = function()
  server_loaded = server_loaded + 1
  if not (server_loaded == 1) then
    return 
  end
  local push_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    push_server = _obj_0.push_server
  end
  local server = assert(push_server("test"), "Failed to start test server")
  server_port = server.port
end
local close_test_server
close_test_server = function()
  server_loaded = server_loaded - 1
  if not (server_loaded == 0) then
    return 
  end
  local pop_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    pop_server = _obj_0.pop_server
  end
  return pop_server()
end
local request
do
  local ltn12 = require("ltn12")
  request = function(url)
    if not (server_loaded > 0) then
      error("The test server is not loaded!")
    end
    local http = require("socket.http")
    local buffer = { }
    local res, status, headers = http.request({
      url = "http://127.0.0.1:" .. tostring(server_port) .. "/" .. tostring(url or ""),
      redirect = false,
      sink = ltn12.sink.table(buffer)
    })
    return table.concat(buffer), status, normalize_headers(headers)
  end
end
return {
  mock_request = mock_request,
  assert_request = assert_request,
  normalize_headers = normalize_headers,
  mock_action = mock_action,
  request = request,
  load_test_server = load_test_server,
  close_test_server = close_test_server
}