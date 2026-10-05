// Shared building blocks so every dashboard gets the same variables, defaults and panel styling.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local var = g.dashboard.variable;
local ts = g.panel.timeSeries;
local stat = g.panel.stat;

{
  g:: g,

  // Every query goes through the $datasource variable: no hard-coded datasource UIDs,
  // so the same JSON imports cleanly into any Grafana / Grafana Cloud stack.
  datasource::
    var.datasource.new('datasource', 'prometheus')
    + var.datasource.generalOptions.withLabel('Data source'),

  labelVar(name, label, metric)::
    var.query.new(name)
    + var.query.withDatasourceFromVariable(self.datasource)
    + var.query.queryTypes.withLabelValues(label, metric)
    + var.query.selectionOptions.withMulti()
    + var.query.selectionOptions.withIncludeAll()
    + var.query.refresh.onTime()
    + var.query.withSort(1),

  prom(expr, legend='')::
    g.query.prometheus.new('${datasource}', expr)
    + g.query.prometheus.withLegendFormat(legend),

  timeseries(title, unit, targets, description='')::
    ts.new(title)
    + ts.panelOptions.withDescription(description)
    + ts.queryOptions.withDatasource('prometheus', '${datasource}')
    + ts.queryOptions.withTargets(targets)
    + ts.standardOptions.withUnit(unit)
    + ts.fieldConfig.defaults.custom.withFillOpacity(10)
    + ts.fieldConfig.defaults.custom.withShowPoints('never')
    + ts.options.legend.withDisplayMode('table')
    + ts.options.legend.withPlacement('bottom')
    + ts.options.legend.withCalcs(['mean', 'max', 'lastNotNull'])
    + ts.options.tooltip.withMode('multi'),

  // Thresholds are [[value, color], ...] ascending; the first step is the base colour.
  stat(title, unit, target, steps=[[null, 'green']], description='')::
    stat.new(title)
    + stat.panelOptions.withDescription(description)
    + stat.queryOptions.withDatasource('prometheus', '${datasource}')
    + stat.queryOptions.withTargets([target])
    + stat.standardOptions.withUnit(unit)
    + stat.standardOptions.thresholds.withMode('absolute')
    + stat.standardOptions.thresholds.withSteps([{ value: s[0], color: s[1] } for s in steps])
    + stat.options.withColorMode('background')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

  dashboard(title, uid, tags, description)::
    g.dashboard.new(title)
    + g.dashboard.withUid(uid)
    + g.dashboard.withDescription(description)
    + g.dashboard.withTags(['observability-as-code'] + tags)
    + g.dashboard.withEditable(false)
    + g.dashboard.withRefresh('1m')
    + g.dashboard.withTimezone('browser')
    + g.dashboard.time.withFrom('now-6h')
    + g.dashboard.graphTooltip.withSharedCrosshair(),
}
