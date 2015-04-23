local json = require('json')
local framework = require('framework.lua')
framework.table()
framework.util()
framework.functional()
local stringutil = framework.string

local Plugin = framework.Plugin
local NetDataSource = framework.NetDataSource
local net = require('net')
require('fun')(true) -- Shows a warn when overriding an existing function.

local items = {}

local params = framework.boundary.param
params.name = 'Boundary Disk Use Summary'
params.version = '2.0'

items = params.items or items

local meterDataSource = NetDataSource:new('127.0.0.1', '9192')

function meterDataSource:onFetch(socket)
	socket:write('{"jsonrpc":"2.0","method":"query_metric","id":1,"params":{"match":"system.disk"}}\n')
end

local meterPlugin = Plugin:new(params, meterDataSource)

function meterPlugin:onParseValues(data)
	
  local result = {}
  local parsed = json.parse(data)
  if table.getn(parsed.result.query_metric) > 0 then
    for i = 1, table.getn(parsed.result.query_metric), 3 do

      local metric = {}
      local typestart, typeend = string.find(parsed.result.query_metric[i], "system.disk.")
      typestart = typeend+1
      typeend = string.find(parsed.result.query_metric[i], "%.", typestart) or string.find(parsed.result.query_metric[i], "|", typestart)
      local type = string.sub(parsed.result.query_metric[i], typestart, typeend-1)
      if string.sub(parsed.result.query_metric[i], typeend+1) == "total" then
        metric.metric = "TOTAL_DISK_"..string.upper(type)
        metric.source = meterPlugin.source
        metric.value = parsed.result.query_metric[i+1]
        table.insert(result, metric)
      else
        local dirname = stringutil.urldecode(string.sub(parsed.result.query_metric[i], string.find(parsed.result.query_metric[i], "dir=")+4, string.find(parsed.result.query_metric[i], "&")-1))
        local devname = stringutil.urldecode(string.sub(parsed.result.query_metric[i], string.find(parsed.result.query_metric[i], "dev=")+4, -1))
        local sourcename=meterPlugin.source.."."
        local capture_metric = 0

        for _, item in ipairs(items) do
          if item.dir  then
            if (item.dir == dirname) then
              if item.device then
                if (item.device == devname) then
                  capture_metric = 1
                  sourcename = sourcename..(item.diskname or dirname.."."..devname)
                end
              else
                capture_metric = 1
                sourcename = sourcename..(item.diskname or dirname.."."..devname)
              end
            end
          elseif item.device and (item.device == devname) then
            capture_metric = 1
            sourcename = sourcename..(item.diskname or dirname.."."..devname)
          end
        end
        if capture_metric == 1 then
          metric.metric = "DISK_"..string.upper(type)
          metric.source = '"'..sourcename..'"'
          metric.value = parsed.result.query_metric[i+1]
          table.insert(result, metric)
        end
      end
    end
  end

  return result	

end

meterPlugin:run()
