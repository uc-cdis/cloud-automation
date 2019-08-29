# TL;DR

Reporting tool for gen3 commons resource utilization

## Use

```
gen3 report-tool -r <report-type> [-o <json|plain>]
```
where <report-type> is one of:
* full report all available resources

The output format is set to plain by default


## Example

* `gen3 report-tool -r full`
* `gen3 report-tool report=full`
* `gen3 report-tool -r full -o json`
* `gen3 report-tool --report full --output json`
