(function(){
  var mod;
  module.exports = {
    pkg: {
      name: 'voronoi-treemap',
      version: '0.0.1',
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: [{
        name: "@zbryikt/voronoijs",
        version: "main",
        path: "index.min.js"
      }]
    },
    init: function(arg$){
      var root, context, pubsub;
      root = arg$.root, context = arg$.context, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          context: context
        })
      }).then(function(it){
        return it[0];
      });
    }
  };
  mod = function(arg$){
    var context, d3, ldcolor, voronoi, chart, ref$;
    context = arg$.context;
    d3 = context.d3, ldcolor = context.ldcolor, voronoi = context.voronoi, chart = context.chart;
    return {
      sample: function(){
        return {
          raw: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100].map(function(val){
            return {
              name: "Node " + val,
              val: (Math.random() * 10).toFixed(2),
              cat: "C-" + Math.floor(1 + 10 * Math.random())
            };
          }),
          binding: {
            name: {
              key: 'name'
            },
            area: {
              key: 'val'
            },
            category: {
              key: 'cat'
            }
          }
        };
      },
      config: (ref$ = chart.utils.config.from({
        preset: 'default',
        label: 'label',
        legend: 'legend'
      }), ref$.voronoi = {
        maxCount: {
          type: 'number',
          min: 1,
          max: 200,
          step: 1,
          'default': 100
        },
        preserve: {
          type: 'choice',
          values: ["Larger Value", "Smaller Value", "As Input Order"]
        }
      }, ref$.border = {
        color: {
          type: 'color',
          'default': '#fff'
        },
        strokeWidth: {
          type: 'number',
          'default': 1,
          min: 0,
          max: 100,
          step: 1
        }
      }, ref$),
      dimension: {
        area: {
          type: 'R',
          name: "area"
        },
        name: {
          type: 'N',
          desc: "name"
        },
        category: {
          type: 'N',
          desc: "category"
        }
      },
      init: function(){
        var tint, g, this$ = this;
        this.tint = tint = new chart.utils.tint();
        this.g = Object.fromEntries(['view', 'legend'].map(function(it){
          return [it, d3.select(this$.layout.getGroup(it))];
        }));
        this.layout.getGroup('view').appendChild(g = document.createElementNS("http://www.w3.org/2000/svg", "g"));
        this.g.shape = d3.select(g);
        this.siteBoxes = [];
        this.legend = new chart.utils.legend({
          layout: this.layout,
          name: 'legend',
          root: this.root,
          shape: function(d){
            return d3.select(this).attr('fill', tint.get(d.key));
          },
          cfg: {
            selectable: true
          }
        });
        this.legend.on('select', function(){
          this$.parse();
          this$.bind();
          this$.resize();
          return this$.render();
        });
        this.tip = new chart.utils.tip({
          root: this.root,
          accessor: function(arg$){
            var evt, data;
            evt = arg$.evt;
            if (!(evt.target && (data = d3.select(evt.target).datum()))) {
              return null;
            }
            if (Array.isArray(data)) {
              if (!this$._sites) {
                return;
              }
              if (!(data.idx != null)) {
                return;
              }
              if (!(data = this$._sites[data.idx])) {
                return;
              }
            }
            return {
              name: data.name,
              value: this$.fmt(data.area || 0) + "" + ((this$.binding.area || {}).unit || '')
            };
          },
          range: function(){
            return this$.layout.getNode('view').getBoundingClientRect();
          }
        });
        return this.start();
      },
      parse: function(){
        var ref$;
        this.data.map(function(it){
          return it.key = it.name, it.value = it.area, it;
        });
        this.partial = this.data.slice(0);
        if (this.cfg.voronoi.preserve === "Larger Value") {
          this.partial.sort(function(a, b){
            return b.value - a.value;
          });
        } else if (this.cfg.voronoi.preserve === "Smaller Value") {
          this.partial.sort(function(a, b){
            return a.value - b.value;
          });
        }
        this.partial = this.partial.slice(0, ((ref$ = this.cfg).voronoi || (ref$.voronoi = {})).maxCount || 100);
        this.total = this.partial.reduce(function(a, b){
          return a + b.area;
        }, 0);
        this.cats = Array.from(new Set(this.partial.map(function(d){
          return d.category;
        }))).filter(function(it){
          return it != null;
        });
        return this.legend.data(this.cats.map(function(it){
          return {
            key: it,
            text: it
          };
        }));
      },
      resize: function(){
        var ref$, rbox, lbox, w, h, size, data, sites, x$, y$, this$ = this;
        this.tip.toggle(((ref$ = this.cfg).tip || (ref$.tip = {})).enabled != null ? this.cfg.tip.enabled : true);
        this.root.querySelector('.pdl-layout').classList.toggle('legend-bottom', this.cfg.legend.position === 'bottom');
        this.legend.config(import$({}, this.cfg.legend));
        this.legend.update();
        this.layout.update(false);
        rbox = this.root.getBoundingClientRect();
        lbox = this.layout.getBox('legend');
        if (this.cfg.legend.position === 'bottom') {
          ref$ = [rbox.width, rbox.height - lbox.height], w = ref$[0], h = ref$[1];
        } else {
          ref$ = [rbox.width - lbox.width, rbox.height], w = ref$[0], h = ref$[1];
        }
        w = h = size = w > h ? h : w;
        ref$ = this.layout.getNode('view').style;
        ref$.width = size + "px";
        ref$.height = size + "px";
        this.layout.update(false);
        this.fmt = chart.utils.format.from(this.cfg.label.format);
        data = this.binding.category
          ? this.partial.filter(function(it){
            return this$.legend.isSelected(it.category);
          })
          : this.partial;
        this.parsed = {
          children: d3.nest().key(function(it){
            return it.category;
          }).entries(data).map(function(it){
            return it.children = it.values, it;
          })
        };
        this.treemap = new voronoi.Treemap(this.parsed, voronoi.Polygon.create(w, h, 60), w, h);
        sites = this.treemap.getSites();
        x$ = this.g.shape.selectAll('path.data').data(this.treemap.getPolygons());
        x$.exit().remove();
        x$.enter().append('path').attr('class', 'data').each(function(d, i){
          return d.idx = i;
        });
        this.g.shape.selectAll('path.data').attr('class', function(d, i){
          if (sites[i].lv <= 0) {
            return 'data group';
          } else {
            return 'data';
          }
        });
        this.polygons = this.g.shape.selectAll('path.data');
        y$ = this.g.shape.selectAll('g.label').data(sites);
        y$.exit().remove();
        y$.enter().append('g').attr('class', 'label').each(function(d, i){
          var x$;
          x$ = d3.select(this);
          x$.append('text').attr('class', 'name').attr('font-size', '.8em');
          x$.append('text').attr('class', 'value');
          return x$;
        });
        this.sites = this.g.shape.selectAll('g.label');
        this.sites.attr('font-size', this.cfg.font.size);
        this.sites.each(function(d, i){
          return d3.select(this).selectAll('text').data([d, d]).attr('text-anchor', 'middle').attr('dominant-baseline', 'center');
        });
        this.scale = {
          x: d3.scaleLinear().domain([0, w]).range([0, w]),
          y: d3.scaleLinear().domain([0, h]).range([0, h]),
          color: d3.interpolateTurbo
        };
        if (this.cfg != null && this.cfg.palette) {
          this.scale.color = d3.interpolateDiscrete(this.cfg.palette.colors.map(function(it){
            return ldcolor.web(it.value || it);
          }));
        }
        this.tint.set(this.cfg.palette);
        sites = this.treemap.getSites();
        this.count = 0;
        return this.gbox = this.svg.getBoundingClientRect();
      },
      render: function(){
        var ticking, sites, polygons, ref$, w, h, siteBoxes, boxes, this$ = this;
        ticking = this.ticking;
        this.ticking = false;
        this._sites = sites = this.treemap.getSites();
        polygons = this.treemap.getPolygons();
        ref$ = [this.box.width, this.box.height], w = ref$[0], h = ref$[1];
        if (!ticking) {
          this.legend.render();
          this.sites.selectAll('.name').attr('dy', '0.88em').text(function(it){
            var n;
            n = (it.name || '') + "";
            return n;
            if (it.lv > 0) {
              return n.substring(0, 7) + (n.length > 7 ? '...' : '');
            } else {
              return '';
            }
          }).attr('fill', function(d, i){
            if (ldcolor.hcl(this$.tint.get(d.category)).l > 60) {
              return '#000';
            } else {
              return '#eee';
            }
          }).style('pointer-events', 'none');
          this.sites.selectAll('.value').attr('dy', '-0.28em').text(function(it){
            if (it.lv > 0) {
              return this$.fmt(it.area || 0);
            } else {
              return '';
            }
          }).attr('fill', function(d, i){
            if (ldcolor.hcl(this$.tint.get(d.category)).l > 60) {
              return '#000';
            } else {
              return '#eee';
            }
          }).style('pointer-events', 'none');
          this.siteBoxes = siteBoxes = [];
          this.sites.each(function(d, i){
            return siteBoxes.push(this.getBoundingClientRect());
          });
          this.polygons.attr('fill', function(d, i){
            return this$.tint.get(sites[i].category);
          }).attr('stroke', this.cfg.border.color).attr('stroke-width', this.cfg.border.strokeWidth);
        }
        siteBoxes = this.siteBoxes;
        boxes = [];
        this.polygons.data(polygons).attr('d', function(d, i){
          var ret, ref$, min, max, i$, to$, idx, x, y;
          d.idx = i;
          if (!(d && d.length)) {
            boxes.push({});
            return "";
          }
          ret = [['M', d[0].x, d[0].y]];
          ref$ = [
            {
              x: d[0].x,
              y: d[0].y
            }, {
              x: d[0].x,
              y: d[0].y
            }
          ], min = ref$[0], max = ref$[1];
          for (i$ = 0, to$ = d.length; i$ < to$; ++i$) {
            idx = i$;
            ref$ = [d[idx].x, d[idx].y], x = ref$[0], y = ref$[1];
            if (min.x > x) {
              min.x = x;
            }
            if (max.x < x) {
              max.x = x;
            }
            if (min.y > y) {
              min.y = y;
            }
            if (max.y < y) {
              max.y = y;
            }
            ret.push(['L', x, y]);
          }
          ret.push(['L', d[0].x, d[0].y]);
          boxes.push({
            x: min.x,
            y: min.y,
            width: max.x - min.x,
            height: max.y - min.y
          });
          return ret.map(function(it){
            return it.join(' ');
          }).join(' ');
        });
        this.polygons.attr('opacity', function(d, i){
          var box, x, y, hide;
          box = boxes[i];
          x = box.x + box.width / 2;
          y = box.y + box.height / 2;
          hide = isNaN(box.x + box.y + box.width + box.height);
          if (hide) {
            return 0;
          } else {
            return 1;
          }
        });
        return this.sites.each(function(d, i){
          var box, mybox, x, y, hide;
          box = boxes[i];
          mybox = siteBoxes[i];
          if (!mybox) {
            mybox = this.getBoundingClientRect();
          }
          x = box.x + box.width / 2;
          y = box.y + box.height / 2;
          hide = isNaN(x) || isNaN(y);
          return d3.select(this).attr('transform', function(){
            var x, y, ref$;
            x = box.x + box.width / 2;
            y = box.y + box.height / 2;
            if (hide) {
              ref$ = [-10000, -10000], x = ref$[0], y = ref$[1];
            }
            return "translate(" + x + ", " + y + ")";
          }).attr('opacity', function(){
            var ref$, ref1$, ref2$;
            if (hide) {
              return 0;
            } else {
              return (ref$ = 1 - 6 * ((ref1$ = mybox.width / ((ref2$ = box.width) > 0 ? ref2$ : 0) - 1) > 0 ? ref1$ : 0)) > 0 ? ref$ : 0;
            }
          }).style('pointer-events', function(){
            if (hide) {
              return 'none';
            } else {
              return '';
            }
          });
        });
      },
      tick: function(){
        if (!this.treemap) {
          return;
        }
        this.count = (this.count || 0) + 1;
        if (this.count < 100) {
          this.ticking = true;
          this.treemap.compute();
          return this.render();
        }
      }
    };
  };
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
