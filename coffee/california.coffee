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
  max: 2000


  constructor: ->
    @appendControls()

    @svg = d3.select('body').append('svg')
      .attr('width', @width)
      .attr('height', @height)
    projection = d3.geo.albers()
      .scale(5000)
      .rotate([122.2500, 0, 0])
      .center([0, 37.0500])
      .parallels([36, 35])
      .translate([@width / 4, @height / 2])
    @path = d3.geo.path()
      .projection(projection)
    @colors = d3.scale.linear()
      .domain([0, @max/2, @max])
      .range(['#fff', 'yellow', 'red'])
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
      .style('stroke', 'black')
      .style('stroke-width', '1pt')
      .style('fill', 'none')


  appendCounties: (counties) ->
    @counties = @svg.selectAll('.county')
      .data(topojson.feature(counties, counties.objects.california_counties).features)
      .enter().append('path')
      .attr('class', '.county')
      .attr('d', @path)


  loadPopulationData: (year, race) ->
    d3.csv("data/race_by_county_#{year}.csv", (error, csv_data) =>
      pop = {}
      (pop[county["County"]] = county) for county in csv_data

      colorWrapper = (value, area, county) =>
        v = parseInt(value.replace(/\,/g, ""))
        @colors(v / area)

      @counties.transition().style('fill', (d) =>
        colorWrapper(pop[d.properties.name][race], @path.area(d), d.properties.name)
      )
    )

  applyOutline: ->



window.map = new CountyMap
