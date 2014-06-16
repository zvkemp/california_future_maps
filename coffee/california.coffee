class CountyMapControls
  constructor: (map) ->
    controls = d3.select('body').append('div')
    years = controls.append('select')
    years.selectAll('option').data([2010, 2020, 2030, 2040, 2050, 2060])
      .enter()
      .append('option')
      .attr('value', (d) -> d)
      .text((d) -> d)
    races = controls.append('select')
    races.selectAll('option').data([
      'Total (All race groups)'
      'White'
      'Black'
      'American Indian'
      'Asian'
      'Native Hawaiian and other Pacific Islander'
      'Hispanic or Latino'
      'Multi-Race']
    ).enter()
      .append('option')
      .attr('value', (d) -> d)
      .text((d) -> d)
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    changeEvent = -> map.loadPopulationData(selectedYear(), selectedRace())
    years.on('change', changeEvent)
    races.on('change', changeEvent)

class CountyMap
  height: 960
  width: 1160
  max: 200

  constructor: ->
    @appendControls()

    @svg = d3.select('body').append('svg')
      .attr('width', @width)
      .attr('height', @height)
    projection = d3.geo.albers()
      .scale(15000)
      .rotate([122.2500, 0, 0])
      .center([0, 37.6500])
      .parallels([36, 35])
      .translate([@width / 4, @height / 2])
    @path = d3.geo.path()
      .projection(projection)
    @colors = d3.scale.linear()
      .domain([0, @max, 1000000])
      .range(['#fff', '#3498db', '#3498db'])
    d3.json('data/cali.json', (error, counties) =>
      @appendCounties(counties)
      @appendOutline(counties)
      @loadPopulationData 2010, 'Total (All race groups)'
    )

  appendControls: -> new CountyMapControls @

  appendOutline: (counties) ->
    @svg.append('path')
      .datum(topojson.mesh(counties, counties.objects.california_counties, (a, b) -> a == b and a.id == b.id))
      .attr('class', 'outline')
      .attr('d', @path)
      .style('stroke', 'gray')
      .style('stroke-width', '0.5pt')
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
      .style('stroke-dasharray', '2, 4')
      .style('fill', 'none')

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
    @hoverLayer
      .on('mouseover', (d) -> d3.select(@).style('opacity', 1))
      .on('mouseout', -> d3.select(@).style('opacity', 0))

  loadPopulationData: (year, race) ->
    d3.csv("data/race_by_county_#{year}.csv", (error, csv_data) =>
      pop = {}
      (pop[county["County"]] = county) for county in csv_data

      colorWrapper = (value, divisor, county) =>
        v = parseInt(value.replace(/\,/g, ""))
        @colors(v / divisor)

      @counties.selectAll('path.fill').transition().style('fill', (d) =>
        colorWrapper(pop[d.properties.name][race], @path.area(d), d.properties.name)
      )
    )

new CountyMap
