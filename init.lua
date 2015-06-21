local framework = require('framework.lua')
local Plugin = framework.Plugin
local MeterDataSource = framework.MeterDataSource
local isEmpty = framework.string.isEmpty
local urldecode = framework.string.urldecode
local params = framework.params
local pack = framework.util.pack

params.items = params.items or {}

local ds = MeterDataSource:new()
function ds:onFetch(socket)
  socket:write(self:queryMetricCommand({match = "system.disk" }))
end

local plugin = Plugin:new(params, ds)

local metric_mapping = {
  ['system.disk.reads.total'] = 'DISK_READS_TOTAL',
  ['system.disk.reads'] = 'DISK_READS',
  ['system.disk.read_bytes.total'] = 'DISK_READ_BYTES_TOTAL',
  ['system.disk.read_bytes'] = 'DISK_READ_BYTES',
  ['system.disk.writes.total'] = 'DISK_WRITES_TOTAL',
  ['system.disk.writes'] = 'DISK_WRITES',
  ['system.disk.write_bytes.total'] = 'DISK_WRITE_BYTES_TOTAL',
  ['system.disk.write_bytes'] = 'DISK_WRITE_BYTES',
  ['system.disk.ios'] = 'DISK_IOS'
}

function plugin:onParseValues(data)
  local result = {}
  for i, v in ipairs(data) do
    local metric, rest = string.match(v.metric, '(system%.disk%.[^|]+)|?(.*)')
    local boundary_metric = metric_mapping[metric]
    if string.find(metric, 'total') then
      result[boundary_metric] = { value = v.value, timestamp = v.timestamp }
    elseif not isEmpty(rest) then
      local dir, dev = string.match(rest, '^dir=(.+)&dev=(.+)')
      dir = urldecode(dir)
      dev = urldecode(dev)
      for _, item in ipairs(params.items) do
        if (item.dir == dir and item.device == dev) or (item.dir and (not item.device or item.device == "") and item.dir == dir) or ((not item.dir or item.dir == "") and item.device and item.device == dev) then
          local source = self.source .. '.' .. (item.diskname or dir .. '.' .. dev) 
          table.insert(result, pack(boundary_metric, v.value, v.timestamp, source))
          break
        end
      end
    end
  end
  return result
end	

plugin:run()
