local framework = require('framework.lua')
local Plugin = framework.Plugin
local MeterDataSource = framework.MeterDataSource
local isEmpty = framework.string.isEmpty
local urldecode = framework.string.urldecode
local params = framework.params
params.name = 'Boundary Disk Use Summary'
params.version = '2.2'

params.items = params.items or {}

local meterDataSource = MeterDataSource:new()
function meterDataSource:onFetch(socket)
  socket:write(self:queryMetricCommand({match = "system.disk" }))
end

local meterPlugin = Plugin:new(params, meterDataSource)

local metric_mapping = {
  ['system.disk.reads.total'] = 'TOTAL_DISK_READS',
  ['system.disk.reads'] = 'DISK_READS',
  ['system.disk.read_bytes.total'] = 'TOTAL_DISK_READ_BYTES',
  ['system.disk.read_bytes'] = 'DISK_READ_BYTES',
  ['system.disk.writes.total'] = 'TOTAL_DISK_WRITES',
  ['system.disk.writes'] = 'DISK_WRITES',
  ['system.disk.write_bytes.total'] = 'TOTAL_DISK_WRITE_BYTES',
  ['system.disk.write_bytes'] = 'DISK_WRITE_BYTES',
  ['system.disk.ios'] = 'DISK_IOS'
}

function meterPlugin:onParseValues(data)
  local result = {}
  for i, v in ipairs(data) do
    local metric, rest = string.match(v.metric, '(system%.disk%.[^|]+)|?(.*)')
    local source = self.source 
    local boundary_metric = metric_mapping[metric]
    if string.find(metric, 'total') then
      result[boundary_metric] = { value = v.value, source = source }
    elseif not isEmpty(rest) then
      local dir, dev = string.match(rest, '^dir=(.+)&dev=(.+)')
      dir = urldecode(dir)
      dev = urldecode(dev)
      for _, item in ipairs(params.items) do
        if (item.dir == dir and item.device == dev) or (item.dir and not item.device and item.dir == dir) or (not item.dir and item.device and item.device == dev) then
          source = self.source .. '.' .. (item.diskname or dir .. '.' .. dev) 
          source = string.gsub(source, "([!@#$%%^&*() {}<>/\\|]", "-")
          result[boundary_metric] = { value = v.value, source = source }
          break
        end
      end
    end
  end
  return result
end	

meterPlugin:run()
