# Change Logs

## v0.0.3

 - extend the lite base ( `@makechart/base` `lite/index.html`, no d3 ): needs `@makechart/base` >= 0.2.0
   and `@plotdb/chart` >= 3.7.0.
   the layout computing in `mod.tick` follows `chart.anim` too, so it can be recorded frame by frame
 - add test cases ( `test/index.ls`, run with `npm test` via `@makechart/viewer` )


## v0.0.2

 - remove d3.nest, instead using d3.group for d3 version compatibility


## v0.0.1

init release
