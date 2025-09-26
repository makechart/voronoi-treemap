module.exports =
  pkg:
    name: 'voronoi-treemap', version: '0.0.1'
    extend: {name: "@makechart/base"}
    dependencies: [
      {name: "@zbryikt/voronoijs", version: "main", path: "index.min.js"}
    ]
  init: ({root, context, pubsub}) ->
    pubsub.fire \init, mod: mod {context} .then ~> it.0

mod = ({context}) ->
  {d3,ldcolor,voronoi,chart} = context
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
    @g = Object.fromEntries <[view legend]>.map ~> [it, d3.select(@layout.get-group it)]
    @layout.get-group(\view).appendChild g = (document.createElementNS "http://www.w3.org/2000/svg", "g")
    @g.shape = d3.select g
    @site-boxes = []
    @legend = new chart.utils.legend do
      layout: @layout
      name: \legend
      root: @root
      shape: (d) -> d3.select(@).attr \fill, tint.get d.key
      cfg: selectable: true
    @legend.on \select, ~> @parse!; @bind!; @resize!; @render!
    @tip = new chart.utils.tip do
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and data = d3.select(evt.target).datum!) => return null
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
    @parsed = children: d3.nest!.key(->it.category).entries(data).map -> it <<< {children: it.values}
    @treemap = new voronoi.Treemap(@parsed, voronoi.Polygon.create(w, h, 60), w, h)
    sites = @treemap.getSites!
    @g.shape.selectAll \path.data .data @treemap.getPolygons!
      ..exit!remove!
      ..enter!append \path
        .attr \class, \data
        .each (d,i) -> d.idx = i
    @g.shape.selectAll \path.data .attr \class, (d,i) -> if sites[i].lv <= 0 => 'data group' else 'data'
    @polygons = @g.shape.selectAll \path.data

    @g.shape.selectAll \g.label .data sites
      ..exit!remove!
      ..enter!append \g .attr \class, \label
        .each (d,i) ->
          d3.select @
            ..append \text .attr \class, 'name' .attr \font-size, '.8em'
            ..append \text .attr \class, 'value'
    @sites = @g.shape.selectAll \g.label
    @sites.attr \font-size, @cfg.font.size
    @sites.each (d,i) ->
      d3.select @ .selectAll \text .data [d,d]
        .attr \text-anchor, \middle
        .attr \dominant-baseline, \center

    @scale =
      x: d3.scaleLinear!domain [0,w] .range [0, w]
      y: d3.scaleLinear!domain [0,h] .range [0, h]
      color: d3.interpolateTurbo
    if @cfg? and @cfg.palette =>
      @scale.color = d3.interpolateDiscrete @cfg.palette.colors.map -> ldcolor.web(it.value or it)
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
      @sites.selectAll \.name
        .attr \dy, \0.88em
        .text ->
          n = ("#{it.name or ''}")
          return n
          if it.lv > 0 => n.substring(0,7) + (if n.length > 7 => '...' else '') else ''
        .attr \fill, (d,i) ~> if ldcolor.hcl(@tint.get d.category).l > 60 => \#000 else \#eee
        .style \pointer-events, \none
      @sites.selectAll \.value
        .attr \dy, \-0.28em
        .text ~> if it.lv > 0 => @fmt(it.area or 0) else ''
        .attr \fill, (d,i) ~> if ldcolor.hcl(@tint.get d.category).l > 60 => \#000 else \#eee
        .style \pointer-events, \none
      @site-boxes = site-boxes = []
      @sites.each (d,i) -> site-boxes.push @getBoundingClientRect!
      @polygons
        .attr \fill, (d,i) ~> @tint.get sites[i].category
        .attr \stroke, @cfg.border.color
        .attr \stroke-width, @cfg.border.stroke-width

    site-boxes = @site-boxes
    boxes = []

    @polygons.data polygons
      .attr \d, (d,i) ->
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
    @polygons
      .attr \opacity, (d,i) ->
        box = boxes[i]
        x = box.x + box.width / 2
        y = box.y + box.height / 2
        hide = isNaN(box.x + box.y + box.width + box.height)
        if hide => 0 else 1
    @sites
      .each (d,i) ->
        box = boxes[i]
        mybox = site-boxes[i]
        if !mybox => mybox = @getBoundingClientRect!
        x = box.x + box.width / 2
        y = box.y + box.height / 2
        hide = (isNaN(x) or isNaN(y))
        d3.select @
          .attr \transform, ->
            x = box.x + box.width / 2
            y = box.y + box.height / 2
            if hide => [x,y] = [-10000,-10000]
            return "translate(#x, #y)"
          .attr \opacity, ->
            if hide => 0
            else (1 - 6 * ((mybox.width / (box.width >? 0) - 1) >? 0)) >? 0
          .style \pointer-events, -> if hide => \none else ''

  tick: ->
    if !@treemap => return
    @count = (@count or 0) + 1
    if @count < 100 =>
      @ticking = true
      @treemap.compute!
      @render!
