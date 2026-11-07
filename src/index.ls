module.exports =
  pkg:
    name: '@makechart/voronoi-treemap', version: '0.0.2'
    # lite: 不帶 d3 的 base ( 見 @plotdb/chart utils )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: [
      {name: "@zbryikt/voronoijs", version: "main", path: "index.min.js"}
    ]
  init: ({root, context, pubsub}) ->
    pubsub.fire \init, mod: mod {context} .then ~> it.0

mod = ({context}) ->
  {ldcolor,voronoi,chart} = context
  {scale: Scale, color: {turbo, discrete}, anim: {join}} = chart.utils
  svgns = "http://www.w3.org/2000/svg"
  # 同 d3.group: 依 key 分組, 保留第一次出現的順序
  group = (list, key) ->
    m = new Map!
    list.map -> if m.has(k = key it) => m.get(k).push it else m.set k, [it]
    m
  set-attr = (n, k, v) -> if v? => n.setAttribute k, v else n.removeAttribute k
  sample: ->
    raw: [0 to 100].map (val) ~>
      name: "Node #val"
      val: (Math.random! * 10).toFixed(2)
      cat: "C-#{Math.floor(1 + 10 * Math.random!)}"
    binding:
      name: {key: \name}
      area: {key: \val}
      category: {key: \cat}
  config: chart.utils.config.from({
    preset: \default
    label: \label
    legend: \legend
  }) <<<
    voronoi:
      max-count: type: \number, min: 1, max: 200, step: 1, default: 100
      preserve: type: \choice, values: ["Larger Value", "Smaller Value", "As Input Order"]
    border:
      color: type: \color, default: \#fff
      stroke-width: type: \number, default: 1, min: 0, max: 100, step: 1
  dimension:
    area: { type: \R, name: "area"},
    name: { type: \N, desc: "name" },
    category: { type: \N, desc: "category"},
  init: ->
    @tint = tint = new chart.utils.tint!
    @g = Object.fromEntries <[view legend]>.map ~> [it, @layout.get-group it]
    @g.shape = @g.view.appendChild document.createElementNS(svgns, \g)
    @site-boxes = []
    @legend = new chart.utils.legend do
      layout: @layout
      name: \legend
      root: @root
      shape: (d) -> @setAttribute \fill, tint.get d.key
      cfg: selectable: true
    @legend.on \select, ~> @parse!; @bind!; @resize!; @render!
    @tip = new chart.utils.tip do
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and data = evt.target.__data__) => return null
        if Array.isArray(data) =>
          if !@_sites => return
          if !(data.idx?) => return
          if !(data = @_sites[data.idx]) => return
        return
          name: data.name
          value: "#{@fmt(data.area or 0)}#{(@binding.area or {}).unit or ''}"
      range: ~> @layout.get-node \view .getBoundingClientRect!
    @start!
  parse: ->
    @data.map -> it <<< {key: it.name, value: it.area}
    @partial = @data.slice 0
    if @cfg.voronoi.preserve == "Larger Value" => @partial.sort (a,b) -> b.value - a.value
    else if @cfg.voronoi.preserve == "Smaller Value" => @partial.sort (a,b) -> a.value - b.value
    @partial = @partial.slice 0, (@cfg.{}voronoi.max-count or 100)
    @total = @partial.reduce(((a,b) -> a + b.area), 0)
    @cats = Array.from(new Set(@partial.map (d) -> d.category)).filter -> it?
    @legend.data @cats.map -> {key: it, text: it}

  resize: ->
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, (@cfg.legend.position == \bottom)
    @legend.config({} <<< @cfg.legend)
    @legend.update!
    @layout.update false
    rbox = @root.getBoundingClientRect!
    lbox = @layout.get-box \legend
    if @cfg.legend.position == \bottom =>
      [w, h] = [rbox.width, rbox.height - lbox.height]
    else
      [w, h] = [rbox.width - lbox.width, rbox.height]
    w = h = size = if w > h => h else w
    @layout.get-node \view .style <<<
      width: "#{size}px", height: "#{size}px"
    @layout.update false

    @fmt = chart.utils.format.from @cfg.label.format
    data = if @binding.category => @partial.filter ~> @legend.is-selected(it.category)
    else @partial
    @parsed = children: Array.from(group(data, ->it.category), ([key, values]) -> {key, values, children: values})
    @treemap = new voronoi.Treemap(@parsed, voronoi.Polygon.create(w, h, 60), w, h)
    sites = @treemap.getSites!
    pj = join root: @g.shape, tag: \path, cls: \data, data: @treemap.getPolygons!
    pj.exit.map -> it.remove!
    pj.enter.map -> it.__data__.idx = pj.nodes.indexOf(it)
    pj.nodes.map (n, i) -> n.setAttribute \class, (if sites[i].lv <= 0 => 'data group' else 'data')
    @polygons = pj.nodes

    lj = join root: @g.shape, tag: \g, cls: \label, data: sites
    lj.exit.map -> it.remove!
    lj.enter.map (n) ->
      n.appendChild document.createElementNS(svgns, \text)
        ..setAttribute \class, \name
        ..setAttribute \font-size, '.8em'
      n.appendChild document.createElementNS(svgns, \text)
        ..setAttribute \class, \value
    @sites = lj.nodes
    @sites.map (n) ~>
      set-attr n, \font-size, @cfg.font.size
      d = n.__data__
      Array.from(n.querySelectorAll \text).map (t) ->
        t.__data__ = d
        t.setAttribute \text-anchor, \middle
        t.setAttribute \dominant-baseline, \center

    @scale =
      x: Scale.linear!domain [0,w] .range [0, w]
      y: Scale.linear!domain [0,h] .range [0, h]
      color: turbo
    if @cfg? and @cfg.palette =>
      @scale.color = discrete @cfg.palette.colors.map -> ldcolor.web(it.value or it)
    @tint.set @cfg.palette
    sites = @treemap.getSites!
    @count = 0
    @gbox = @svg.getBoundingClientRect!

  render: ->
    ticking = @ticking
    @ticking = false
    @_sites = sites = @treemap.getSites!
    polygons = @treemap.getPolygons!
    [w,h] = [@box.width, @box.height]
    if !ticking =>
      @legend.render!
      fill = (d) ~> if ldcolor.hcl(@tint.get d.category).l > 60 => \#000 else \#eee
      @sites.map (n) ~>
        d = n.__data__
        [tn, tv] = n.querySelectorAll \text
        tn
          ..setAttribute \dy, \0.88em
          ..textContent = "#{d.name or ''}"
          ..setAttribute \fill, fill(d)
          ..style.pointerEvents = \none
        tv
          ..setAttribute \dy, \-0.28em
          ..textContent = if d.lv > 0 => @fmt(d.area or 0) else ''
          ..setAttribute \fill, fill(d)
          ..style.pointerEvents = \none
      @site-boxes = @sites.map -> it.getBoundingClientRect!
      @polygons.map (n, i) ~>
        n.setAttribute \fill, @tint.get sites[i].category
        n.setAttribute \stroke, @cfg.border.color
        n.setAttribute \stroke-width, @cfg.border.stroke-width

    site-boxes = @site-boxes
    boxes = []

    # 同 d3 的 selection.data: 只更新現有的 path, 多的資料不管
    @polygons.slice(0, polygons.length).map (n, i) ->
      d = n.__data__ = polygons[i]
      n.setAttribute \d, do ->
        d.idx = i
        if !(d and d.length) =>
          boxes.push {}
          return ""
        ret = [[\M, d.0.x, d.0.y]]
        [min,max] = [{x: d.0.x, y: d.0.y}, {d.0.x, d.0.y}]
        for idx from 0 til d.length =>
          [x,y] = [d[idx].x, d[idx].y]
          if min.x > x => min.x = x
          if max.x < x => max.x = x
          if min.y > y => min.y = y
          if max.y < y => max.y = y
          ret.push [\L, x, y]
        ret.push [\L, d.0.x, d.0.y]
        boxes.push {x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y}
        return ret.map(->it.join(' ')).join(' ')

    # attempt to hide unwanted outlier polygon, however seem to not work very well..?
    @polygons.map (n, i) ->
      box = boxes[i]
      hide = isNaN(box.x + box.y + box.width + box.height)
      n.setAttribute \opacity, if hide => 0 else 1
    @sites.map (n, i) ->
      box = boxes[i]
      mybox = site-boxes[i]
      if !mybox => mybox = n.getBoundingClientRect!
      x = box.x + box.width / 2
      y = box.y + box.height / 2
      hide = (isNaN(x) or isNaN(y))
      if hide => [x,y] = [-10000,-10000]
      n.setAttribute \transform, "translate(#x, #y)"
      n.setAttribute \opacity, (
        if hide => 0
        else (1 - 6 * ((mybox.width / (box.width >? 0) - 1) >? 0)) >? 0
      )
      n.style.pointerEvents = if hide => \none else ''

  tick: ->
    if !@treemap => return
    @count = (@count or 0) + 1
    if @count < 100 =>
      @ticking = true
      @treemap.compute!
      @render!
