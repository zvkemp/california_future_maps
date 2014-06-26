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
    ages.selectAll('option').data(["all"].concat meta.age_group).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    races = controls.append('select')
    races.selectAll('option').data(meta.race).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    #selectedYear = -> years.select('input:checked').node().value
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    changeEvent =  -> map.loadPopulationData(selectedYear(), selectedRace())
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
      d3.csv("data/race_by_county.csv", (error, csv_data) =>
        d3.csv("data/square_miles.csv", (error, area_data) =>
          @square_miles = {}
          (@square_miles[county.county] = parseFloat(county.square_miles)) for county in area_data
          @raw_data = csv_data
          @appendCounties(counties)
          @appendOutline(counties)
          @appendHoverLayer(counties)
          @loadPopulationData( "2010", 'Total (All race groups)')
          @onLoad()

        )
      )
    )



  appendControls: (meta) -> new CountyMapControls @, meta

  appendOutline: (counties) ->
    @svg.append('path')
      .datum(topojson.mesh(counties, counties.objects.california_counties, (a, b) -> a == b and a.id == b.id))
      .attr('class', 'outline')
      .attr('d', @path)
      .style('stroke', 'gray')
      .style('stroke-width', '1pt')
      .style('fill', 'none')
    # bay area outline
    @svg.append('path')
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

  appendCounties: (counties) =>
    # This seems a little convuluted, but all is necessary to provide nice, non-overlapping
    # tooltips (outlines and county metadata) on mouseover.
    @counties = @svg.selectAll('.county')
      .data(topojson.feature(counties, counties.objects.california_counties).features)
      .enter().append('g')
      .attr('class', '.county')
    @counties.append('path').attr('class', 'fill')
      .datum((d) -> d)
      .attr('d', @path)

  appendHoverLayer: (counties) =>
    @hoverLayer = @svg.selectAll('.county_hover')
      .data(topojson.feature(counties, counties.objects.california_counties).features)
      .enter()
      .append('g')
      .attr('class', 'tooltip')
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
      .style('font-family', 'arial')
      .style('font-weight', 'bold')
      .style('font-size', '8pt')
      .style('stroke', 'white')
      .style('stroke-width', '2pt')
    @hoverLayer.append('text')
      .text((d) -> d.properties.name)
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1])
      .attr('text-anchor', 'middle')
      .style('font-family', 'arial')
      .style('font-weight', 'bold')
      .style('font-size', '8pt')
    @hoverLayer.append('text')
      .attr('class', 'density')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-family', 'arial')
      .style('font-size', '8pt')
      .style('stroke', 'white')
      .style('stroke-width', '2pt')
      .style('font-weight', 'bold')
    @hoverLayer.append('text')
      .attr('class', 'density')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
      .attr('text-anchor', 'middle')
      .style('font-family', 'arial')
      .style('font-size', '8pt')
      .style('font-weight', 'bold')
    @hoverLayer
      .on('mouseover', (d) -> d3.select(@).style('opacity', 1))
      .on('mouseout', -> d3.select(@).style('opacity', 0))

  loadPopulationData: (year, race) ->
    pop = {}
    (pop[county["County"]] = county) for county in @raw_data when county["YEAR"] is year

    colorWrapper = (value, divisor, county) =>
      v = parseInt(value)
      @colors(v / divisor)

    @counties.selectAll('path.fill').transition().style('fill', (d) =>
      #colorWrapper( pop[d.properties.name][race], @square_miles[d.properties.name], d.properties.name)
      colorWrapper( pop[d.properties.name][race], pop[d.properties.name]["Total (All race groups)"], d.properties.name)
    )

    @hoverLayer.selectAll('text.density')
      .text((d) =>
        "#{d3.round(100 * parseInt(pop[d.properties.name][race]) / pop[d.properties.name]["Total (All race groups)"],1)}%"
        #"#{(parseInt(pop[d.properties.name][race]) / @square_miles[d.properties.name]).toFixed(1)} per sq. mile"
      )

d3.json("/meta.json", (meta) ->
  map = new CountyMap(meta)
)
