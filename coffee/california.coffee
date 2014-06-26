id = (d) -> d

class CountyMapControls
  constructor: (map, meta) ->
    controls = d3.select('body').append('div')
    #years = controls.append('div')
    #years.selectAll('input').data(meta.year)
    #.enter()
    #.append('label')
    #.text((d) -> d)
    #.append('input')
    #.attr('type', 'radio')
    #.attr('name', 'year')
    #.attr('value', (d) -> d)

    years = controls.append('select')
    years.selectAll('option').data(meta.year).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    ages = controls.append('select')
    age_data = ({ value: g, text: g.replace("..", " to ") } for g in (["all"].concat meta.age_group))
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
    zoom.selectAll('option').data([{ text: "Bay Area", value: 15000 }, { text: "California", value: 5000 }]).enter()
      .append('option')
      .attr('value', (d) -> d.value)
      .text((d) -> d.text)

    zoom.on('change', -> map.zoom(zoom.node().value))

    #selectedYear = -> years.select('input:checked').node().value
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    changeEvent =  -> map.loadPopulationData(selectedYear(), selectedRace(), selectedAge())
    selector.on('change', changeEvent) for selector in [years, races, ages]
    map.onLoad = changeEvent

class CountyMap
  height: 960
  width: 1160
  max: 2000

  onLoad: ->

  constructor: (meta) ->
    @appendControls(meta)
    @svg = d3.select('body').append('svg')
      .attr('width', @width)
      .attr('height', @height)
    @svg.append('rect').attr('width', @width)
      .attr('height', @height)
      .style('fill', 'none')
      .style('stroke', 'gray')
    @projection = d3.geo.albers()
      .scale(15000)
      .rotate([122.2500, 0, 0])
      .center([0, 37.3500])
      .parallels([36, 35])
      .translate([@width / 4, @height / 2])
    @path = d3.geo.path()
      .projection(@projection)
    @colors = d3.scale.linear()
      #.domain([0, @max, 30000])
      .domain([0, 0.25, 1])
      .range(['#fff', '#3498DB', '#E74C3C'])

    d3.json('data/cali.json', (error, counties) =>
      d3.csv("data/square_miles.csv", (error, area_data) =>
        @square_miles = {}
        (@square_miles[county.county] = parseFloat(county.square_miles)) for county in area_data
        @appendCounties(counties)
        @appendOutline(counties)
        @appendHoverLayer(counties)
        @appendLegend()
        @onLoad()
      )
    )

  appendLegend: ->
    @legend = @svg.append('g').attr('id', 'legend')
      .attr('transform', "translate(50, #{@height - 300})")
      .style('stroke', 'gray')
      .style('fill', 'white')
    @legend.append('rect')
      .attr('width', 180)
      .attr('height', 240)

    legendY = (d) -> 200 * d + 10

    @legend.selectAll('rect').data(n for n in [0..1] by 0.1)
      .enter()
      .append('rect')
      .attr('x', 10)
      .attr('y', legendY)
      .attr('width', 20)
      .attr('height', 20)
      .style('stroke', 'white')
      .style('fill', @colors)

    @legend.selectAll('text.percentages').data(n for n in [0..100] by 10)
      .enter()
      .append('text')
      .text((d) -> "#{d}%")
      .attr('transform', (d) -> "translate(35, #{legendY(d/100) + 15})")
      .style('font-family', 'arial')
      .style('font-size', 10)
      .style('font-weight', 'bold')
      .style('fill', 'black')
      .style('stroke', 'none')



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
      .style('font-family', 'arial')
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
      .style('font-family', 'arial')
      .style('font-weight', 'bold')
      .style('font-size', '8pt')
    @hoverLayer.append('text')
      .attr('class', 'value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-family', 'arial')
      .style('font-size', '8pt')
      .style('stroke', 'white')
      .style('stroke-width', '2pt')
      .style('font-weight', 'bold')
    @hoverLayer.append('text')
      .attr('class', 'value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-family', 'arial')
      .style('font-size', '8pt')
      .style('font-weight', 'bold')
    @hoverLayer
      .on('mouseover', (d) -> d3.select(@).style('opacity', 1))
      .on('mouseout', -> d3.select(@).style('opacity', 0))

  #loadPopulationData: (year, race) ->
  #  pop = {}
  #  (pop[county["County"]] = county) for county in @raw_data when county["YEAR"] is year

  #  colorWrapper = (value, divisor, county) =>
  #    v = parseInt(value)
  #    @colors(v / divisor)

  #  @counties.selectAll('path.fill').transition().style('fill', (d) =>
  #    #colorWrapper( pop[d.properties.name][race], @square_miles[d.properties.name], d.properties.name)
  #    colorWrapper( pop[d.properties.name][race], pop[d.properties.name]["Total (All race groups)"], d.properties.name)
  #  )

  #  @hoverLayer.selectAll('text.density')
  #    .text((d) =>
  #      "#{d3.round(100 * parseInt(pop[d.properties.name][race]) / pop[d.properties.name]["Total (All race groups)"],1)}%"
  #      #"#{(parseInt(pop[d.properties.name][race]) / @square_miles[d.properties.name]).toFixed(1)} per sq. mile"
  #    )
  #
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
      )
    )

d3.json("/meta.json", (meta) ->
  window.map = new CountyMap(meta)
)
