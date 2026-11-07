# voronoi-treemap 的 test case ( @makechart/viewer 的 mctest )
# 每份資料用自己的種子, 跟產生的先後順序無關
mk = (n, ncat = 4, seed = n) ->
  rnd = mctest.random seed
  raw: [0 til n].map (i) ->
    {name: "Node #i", val: Math.round(rnd! * 1000) / 100, cat: "C-#{Math.floor(rnd! * ncat)}"}
  binding: {name: {key: \name}, area: {key: \val}, category: {key: \cat}}
# voronoijs 用 Math.random 放初始的 site, 換成固定種子後重建版面 ( resize ), 再跑完 100 次 compute.
# lite 版推 anim 的時鐘, d3 版等真實時間. 種子留到最後一步才換回, 期間的 resize 也用同一組亂數
_random = Math.random
layout = [
  (c) ->
    Math.random = mctest.random 1
    c.parse!; c.bind!; c.resize!; c.render!
  (c, ctx) ->
    if c.anim => for i from 0 til 120 => c.anim.step 16
    else ctx.wait 3000
  -> Math.random = _random
]
pick = (keys) -> (c) ->
  c.legend.select keys
  c.parse!; c.bind!; c.resize!; c.render!

mctest.suite do
  size: [480, 400]
  data:
    many: mk 40
    few: mk 8, 2
  cases:
    * name: "many", data: \many, steps: layout
    * name: "few", data: \few, steps: layout
    * name: "max-count", data: \many, config: {voronoi: {max-count: 10}}, steps: layout
    * name: "preserve:smaller", data: \many, config: {voronoi: {preserve: "Smaller Value", max-count: 10}}, steps: layout
    * name: "border", data: \few, config: {border: {color: \#000, stroke-width: 3}}, steps: layout
    * name: "legend:bottom", data: \many, config: {legend: {position: \bottom}}, steps: layout
    * name: "legend:pick", data: \many, steps: [(pick <[C-0 C-2]>)] ++ layout

# lite 版才有: compute 一步步收斂的中間格
mctest.suite do
  size: [480, 400]
  data: many: mk 40
  cases:
    * name: "anim:compute-frames", data: \many
      steps:
        * layout.0
        * (c, ctx) ->
            for i from 1 to 3
              for j from 0 til 10 => c.anim.step 16
              ctx.capture "f#{i * 10}"
        * layout.2
