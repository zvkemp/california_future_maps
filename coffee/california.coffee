id = (d) -> d

class CountyMapControls
  constructor: (map, meta) ->
    controls = d3.select('body').append('div')

    years = controls.append('select')
    years.selectAll('option').data(meta.year).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    ages = controls.append('select')
    age_data = [{ value: "all", text: "all age groups" }].concat({ value: g, text: "#{g.replace("..", " to ")} year olds" } for g in meta.age_group)
    ages.selectAll('option').data(age_data)
      .enter()
      .append('option')
      .attr('value', (d) -> d.value)
      .text((d) -> d.text)

    races = controls.append('select')
    races.selectAll('option').data(["all"].concat meta.race).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    zoom = controls.append('select')
    zoom.selectAll('option').data([{ text: "Bay Area", value: 14000 }, { text: "California", value: 4500 }]).enter()
      .append('option')
      .attr('value', (d) -> d.value)
      .text((d) -> d.text)

    zoom.on('change', -> map.zoom(zoom.node().value))

    #selectedYear = -> years.select('input:checked').node().value
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    changeEvent  = -> map.loadPopulationData(selectedYear(), selectedRace(), selectedAge())
    selector.on('change', changeEvent) for selector in [years, races, ages]
    map.onLoad = changeEvent

class CountyMap
  height: 800
  width: 1100

  onLoad: ->

  constructor: (meta) ->
    @appendControls(meta)
    @svg = d3.select('body').append('svg')
      .attr('width', @width)
      .attr('height', @height)
    @svg.append('rect').attr('width', @width)
      .attr('height', @height)
      .style('fill', '#f9f9f9')
      .style('stroke', 'gray')
    @projection = d3.geo.albers()
      .scale(14000)
      .rotate([122.8600, 0, 0])
      .center([0, 37.3500])
      .parallels([36, 35])
      .translate([@width / 4, @height / 2])
    @path = d3.geo.path()
      .projection(@projection)
    @colors = d3.scale.linear()
      .domain([0, 0.25, 1])
      .range(['#fff', '#3498DB', '#E74C3C'])
    @_meta = meta

    d3.json('data/cali.json', (error, counties) =>
      @appendCounties(counties)
      @appendOutline(counties)
      @appendHoverLayer(counties)
      @appendLegend()
      @appendLiveLegend()
      @onLoad()
    )

  appendLiveLegend: ->
    @_legendWrapper = @svg.append('foreignObject').attr('x', 30).attr('y', @height - 150).attr('width', 360).attr('height', 200)
    @liveLegend = @_legendWrapper.append('xhtml:div')

    large_text = @liveLegend.append('p').attr('class', 'large')
    small_text = @liveLegend.append('p').attr('class', 'small')
    small_text.append('span').text('AS A PERCENTAGE OF THE TOTAL,')
    years = small_text.append('select').attr('class', 'small')
    years.selectAll('option').data(@_meta.year).enter()
      .append('option')
      .attr('value', id)
      .text(id)
    small_text.append('span').text('ESTIMATE')

    races = large_text.append('select').attr('class', 'large')
    race_data = [{ value: "all", text: "all ethnicities" }].concat({ value: g, text: g} for g in @_meta.race)
    races.selectAll('option').data(race_data).enter()
      .append('option')
      .attr('value', (d) -> d.value)
      .text((d) -> d.text)
    large_text.append('span').text(",")

    ages = large_text.append('select').attr('class', 'large')
    age_data = [{ value: "all", text: "all age groups" }].concat({ value: g, text: "#{g.replace("..", " to ")} year olds" } for g in @_meta.age_group)
    ages.selectAll('option').data(age_data)
      .enter()
      .append('option')
      .attr('value', (d) -> d.value)
      .text((d) -> d.text)

    #selectedYear = -> years.select('input:checked').node().value
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    changeEvent  = -> map.loadPopulationData(selectedYear(), selectedRace(), selectedAge())
    selector.on('change', changeEvent) for selector in [years, races, ages]
    map.onLoad = changeEvent


  appendLegend: ->
    @legend = @svg.append('g').attr('id', 'legend')
      .attr('transform', "translate(30, #{@height - 100})")
    legendX = (d) -> 300 * d + 10
    legendData = (n for n in [0..1] by 0.1)
    @legend.selectAll('rect').data(legendData)
      .enter()
      .append('rect')
      .attr('x', legendX)
      .attr('y', 10)
      .attr('width', 30).attr('height', 30)
      .style('stroke', 'white')
      .style('fill', @colors)
    percent = d3.format("%")
    @legend.selectAll('text.percentage').data(legendData)
      .enter()
      .append('text')
      .attr('transform', (d) -> "translate(#{legendX(d) + 15}, 50)")
      .text(percent)
      .style('text-anchor', 'middle')
      .style('font-size', 10)
      .style('font-weight', 'bold')
    #@legendText = @legend.append('text').attr('id', 'legendText')
    #.text('')
    #.attr('transform', "translate(0, -20)")
    #.style('font-weight', 'bold')
    #.style('font-size', 18)
    #@legendSubText = @legend.append('text').attr('id', 'legendSubText')
    #.text('')
    #.style('font-size', 14)

  #legendTextContent: (year, race, age) ->
  #race       = (if race is "all" then null else "#{race} population")
  #age        = (if age is "all" then null else "#{age.replace('..', " to ")} year olds")
  #prediction = "#{year} ESTIMATE"
  #legend     = (x for x in [race, age] when x)
  #@legendText.text(legend.join(', '))
  #@legendSubText.text("AS A PERCENTAGE OF THE TOTAL, #{prediction}")



  appendControls: (meta) -> new CountyMapControls @, meta

  appendOutline: (counties) ->
    @outline = @svg.append('path')
      .datum(topojson.mesh(counties, counties.objects.california_counties, (a, b) -> a == b and a.id == b.id))
      .attr('class', 'outline')
      .attr('d', @path)
      .style('stroke', 'gray')
      .style('stroke-width', '1pt')
      .style('fill', 'none')
    # bay area outline
    @bay_area = @svg.append('path')
      .datum(
        topojson.merge(
          counties,
          counties.objects.california_counties.geometries.filter((d) -> d.properties.bay_area)
        )
      ).attr('class', 'outline')
      .attr('d', @path)
      .style('stroke', 'black')
      .style('stroke-width', '2pt')
      .style('stroke-dasharray', '3, 4')
      .style('fill', 'none')

  zoom: (scale) =>
    @projection.scale(scale)
    @path.projection(@projection)
    @counties.selectAll('path').transition().attr('d', @path)
    @hoverLayer.selectAll('path').transition().attr('d', @path)
    @hoverLayer.selectAll('text.name')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1])
    @hoverLayer.selectAll('text.value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
    @outline.transition().attr('d', @path)
    @bay_area.transition().attr('d', @path)

  appendCounties: (counties) =>
    # This seems a little convuluted, but all is necessary to provide nice, non-overlapping
    # tooltips (outlines and county metadata) on mouseover.
    @counties = @svg.selectAll('.county')
      .data(topojson.feature(counties, counties.objects.california_counties).features)
      .enter().append('g')
      .attr('class', 'county')
    @counties.append('path').attr('class', 'fill')
      .datum((d) -> d)
      .attr('d', @path)
      .style('fill', 'white')

  appendHoverLayer: (counties) =>
    @hoverLayer = @svg.selectAll('.county_hover')
      .data(topojson.feature(counties, counties.objects.california_counties).features)
      .enter()
      .append('g')
      .attr('class', 'tooltip county_hover')
      .style('opacity', 0)
    @hoverLayer.append('path').datum((d) -> d)
      .attr('d', @path)
      .style('stroke', 'black')
      .style('stroke-width', 2)
      .style('fill', 'white')
      .style('fill-opacity',0)
    @hoverLayer.append('text')
      .text((d) -> d.properties.name)
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1])
      .attr('text-anchor', 'middle')
      .attr('class', 'name')
      .style('font-weight', 'bold')
      .style('font-size', '8pt')
      .style('stroke', 'white')
      .style('stroke-width', '2pt')
    @hoverLayer.append('text')
      .text((d) -> d.properties.name)
      .attr('class', 'name')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1])
      .attr('text-anchor', 'middle')
      .style('font-weight', 'bold')
      .style('font-size', '8pt')
    @hoverLayer.append('text')
      .attr('class', 'value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-size', '8pt')
      .style('stroke', 'white')
      .style('stroke-width', '2pt')
      .style('font-weight', 'bold')
    @hoverLayer.append('text')
      .attr('class', 'value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-size', '8pt')
      .style('font-weight', 'bold')
    @hoverLayer
      .on('mouseover', (d) -> d3.select(@).style('opacity', 1))
      .on('mouseout', -> d3.select(@).style('opacity', 0))

  updateWindow: ->
    x = window.innerWidth
    y = window.innerHeight

  loadPopulationData: (year, race, age) ->
    age or= "all"
    d3.json("/data.json?year=#{year}&race=#{race}&age_group=#{age}&gender=all", (data) =>
      d3.json("/data.json?year=#{year}&race=all&age_group=all&gender=all", (totals) =>
        pop = {}
        (pop[row.county] = row) for row in data
        (pop[row.county].total = row.estimate) for row in totals

        colorWrapper = (value) =>
          @colors(percentageOfTotal(value))

        percentageOfTotal = (d) ->
          p = pop[d.properties.name]
          p.estimate / p.total

        @counties.selectAll('path.fill').transition().style('fill', (d) =>
          @colors(percentageOfTotal(d))
        )
        @hoverLayer.selectAll('text.value')
          .text((d) -> "#{d3.round(100 * percentageOfTotal(d), 1)}%")
        #@legendTextContent(year, race, age)
      )
    )

d3.json("/meta.json", (meta) ->
  window.map = new CountyMap(meta)
)
