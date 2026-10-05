local c = import '../lib/common.libsonnet';
local g = c.g;

// Must match the objective in prometheus/rules/slo-http.rules.yml.
local objective = 0.999;
local budget = 1 - objective;

local job = c.labelVar('job', 'job', 'job:slo_http_errors_per_request:ratio_rate5m');

local errors30d = 'sum by (job) (increase(http_requests_total{job=~"$job", code=~"5.."}[30d]))';
local total30d = 'sum by (job) (increase(http_requests_total{job=~"$job"}[30d]))';

c.dashboard(
  'SLO / HTTP Availability',
  'oac-slo-http',
  ['slo'],
  'HTTP availability SLO (%g%% over 30d) with multi-window burn rates. Paired with prometheus/rules/slo-http.rules.yml.' % (objective * 100),
)
+ g.dashboard.withVariables([c.datasource, job])
+ g.dashboard.time.withFrom('now-7d')
+ g.dashboard.withPanels(
  g.util.grid.makeGrid([
    g.panel.row.new('Objective'),
    c.stat(
      'Availability (30d)',
      'percentunit',
      c.prom('1 - (%s / %s)' % [errors30d, total30d], '{{job}}'),
      [[null, 'red'], [objective, 'green']],
    )
    + g.panel.stat.standardOptions.withDecimals(3),
    c.stat(
      'Error budget remaining (30d)',
      'percentunit',
      c.prom('1 - ((%s / %s) / %g)' % [errors30d, total30d, budget], '{{job}}'),
      [[null, 'red'], [0.25, 'orange'], [0.5, 'green']],
      'Share of the 30d error budget still unspent. Below 0 means the SLO is already blown.',
    ),
    c.stat(
      'Current burn rate (1h)',
      'suffix:x',
      c.prom('job:slo_http_errors_per_request:ratio_rate1h{job=~"$job"} / %g' % budget, '{{job}}'),
      [[null, 'green'], [1, 'orange'], [14.4, 'red']],
      '1x spends exactly the budget over 30d. 14.4x pages (2% of budget in 1h).',
    ),

    g.panel.row.new('Burn rate'),
    c.timeseries('Burn rate by window', 'suffix:x', [
      c.prom('job:slo_http_errors_per_request:ratio_rate5m{job=~"$job"} / %g' % budget, '{{job}} 5m'),
      c.prom('job:slo_http_errors_per_request:ratio_rate1h{job=~"$job"} / %g' % budget, '{{job}} 1h'),
      c.prom('job:slo_http_errors_per_request:ratio_rate6h{job=~"$job"} / %g' % budget, '{{job}} 6h'),
      c.prom('job:slo_http_errors_per_request:ratio_rate1d{job=~"$job"} / %g' % budget, '{{job}} 1d'),
    ], 'Page thresholds: 14.4x (1h & 5m) or 6x (6h & 30m). Ticket: 3x (1d & 2h) or 1x (3d & 6h).'),
    c.timeseries('Request rate', 'reqps', [
      c.prom('sum by (job) (rate(http_requests_total{job=~"$job"}[5m]))', '{{job}} total'),
      c.prom('sum by (job) (rate(http_requests_total{job=~"$job", code=~"5.."}[5m]))', '{{job}} 5xx'),
    ]),
    c.timeseries('Error ratio (5m)', 'percentunit', [
      c.prom('job:slo_http_errors_per_request:ratio_rate5m{job=~"$job"}', '{{job}}'),
    ]),
  ], panelWidth=8, panelHeight=8)
)
