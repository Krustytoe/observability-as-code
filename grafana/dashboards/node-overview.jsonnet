local c = import '../lib/common.libsonnet';
local g = c.g;

local sel = 'job="node", instance=~"$instance"';
local fsSel = sel + ', fstype!~"tmpfs|overlay|squashfs"';

local instance = c.labelVar('instance', 'instance', 'up{job="node"}');

c.dashboard(
  'Linux Hosts / Overview',
  'oac-node-overview',
  ['linux', 'node-exporter'],
  'Fleet health for node_exporter targets. Thresholds match prometheus/rules/node.rules.yml.',
)
+ g.dashboard.withVariables([c.datasource, instance])
+ g.dashboard.withPanels(
  // KPI row: four short tiles on one line (row header y=0, tiles y=1..5).
  g.util.grid.makeGrid([
    g.panel.row.new('Fleet'),
    c.stat('Targets down', 'none', c.prom('count(up{%s} == 0) or vector(0)' % sel), [[null, 'green'], [1, 'red']]),
    c.stat('Max CPU', 'percentunit', c.prom('max(instance:node_cpu_utilisation:rate5m{%s})' % sel), [[null, 'green'], [0.8, 'orange'], [0.9, 'red']]),
    c.stat('Max memory', 'percentunit', c.prom('max(instance:node_memory_utilisation:ratio{%s})' % sel), [[null, 'green'], [0.9, 'orange'], [0.97, 'red']]),
    c.stat(
      'Fullest filesystem',
      'percentunit',
      c.prom('max(1 - node_filesystem_avail_bytes{%s} / node_filesystem_size_bytes{%s})' % [fsSel, fsSel]),
      [[null, 'green'], [0.75, 'orange'], [0.95, 'red']],
    ),
  ], panelWidth=6, panelHeight=5)
  + g.util.grid.makeGrid([
    g.panel.row.new('Compute'),
    c.timeseries('CPU utilisation', 'percentunit', [c.prom('instance:node_cpu_utilisation:rate5m{%s}' % sel, '{{instance}}')])
    + g.panel.timeSeries.standardOptions.withMax(1),
    c.timeseries('Memory utilisation', 'percentunit', [c.prom('instance:node_memory_utilisation:ratio{%s}' % sel, '{{instance}}')])
    + g.panel.timeSeries.standardOptions.withMax(1),
    c.timeseries('Load average (1m) per core', 'short', [
      c.prom('node_load1{%s} / on (instance) count by (instance) (node_cpu_seconds_total{%s, mode="idle"})' % [sel, sel], '{{instance}}'),
    ], 'Sustained values above 1.0 mean runnable work is queueing for CPU.'),

    g.panel.row.new('Storage & network'),
    c.timeseries('Filesystem used', 'percentunit', [
      c.prom('1 - node_filesystem_avail_bytes{%s} / node_filesystem_size_bytes{%s}' % [fsSel, fsSel], '{{instance}} {{mountpoint}}'),
    ])
    + g.panel.timeSeries.standardOptions.withMax(1),
    c.timeseries('Disk I/O time', 'percentunit', [
      c.prom('rate(node_disk_io_time_seconds_total{%s}[5m])' % sel, '{{instance}} {{device}}'),
    ], 'Fraction of time the device was busy; near 100% means saturated.'),
    c.timeseries('Network throughput', 'Bps', [
      c.prom('sum by (instance) (rate(node_network_receive_bytes_total{%s, device!~"lo|veth.*|docker.*|cni.*"}[5m]))' % sel, '{{instance}} rx'),
      c.prom('-sum by (instance) (rate(node_network_transmit_bytes_total{%s, device!~"lo|veth.*|docker.*|cni.*"}[5m]))' % sel, '{{instance}} tx'),
    ], 'Receive above zero, transmit below.'),
  ], panelWidth=8, panelHeight=8, startY=6)
)
