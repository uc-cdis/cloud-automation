import os
from datadog import initialize, statsd

options = {
    'statsd_host':'datadog-agent-cluster-agent.datadog',
    'statsd_port':8125
}

initialize(**options)

def send_metric(metric, tags=None):
    if tags is None:
        tags = []
    try:
        statsd.increment(
            "planx.config_mgmt.{0}".format(metric),
            tags=tags,
        )
    except Exception as e:
        # We don't want Fence to fail on an API error
        print('Couldn\'t send metric "{0}" to Datadog'.format(metric))
        print(e)

if __name__ == '__main__':
  # quick test
  send_metric("feature_flags", 1, ["MOCK_GOOGLE_AUTH:true"])
