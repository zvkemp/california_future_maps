class CountyMap
  height: 960
  width: 1160
  max: 2000000

  constructor: ->
    @controls = d3.select('body').append('div')
    @years = @controls.append('select')
    @years.selectAll('option').data([2010, 2020, 2030, 2040, 2050, 2060])
      .enter()
      .append('option')
      .attr('value', (d) -> d)
      .text((d) -> d)
    @races = @controls.append('select')
    @races.selectAll('option').data([
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

    selectedYear = => @years.node().value
    selectedRace = => @races.node().value
    changeEvent = => @loadPopulationData(selectedYear(), selectedRace())

    @years.on('change', changeEvent)
    @races.on('change', changeEvent)

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
      .range(['#fff', '#00f', 'red'])
    d3.json('data/cali.json', (error, counties) =>
      @counties = @svg.selectAll('.county')
        .data(topojson.feature(counties, counties.objects.california_counties).features)
        .enter().append('path')
        .attr('class', '.county')
        .attr('d', @path)
      @loadPopulationData 2010, 'Total (All race groups)'
    )

  loadPopulationData: (year, race) ->
    d3.csv("data/race_by_county_#{year}.csv", (error, csv_data) =>
      pop = {}
      (pop[county["County"]] = county) for county in csv_data

      colorWrapper = (value) => @colors(value.replace(",",""))
      @counties.style('fill', (d) -> colorWrapper(pop[d.properties.name][race]))
    )


window.map = new CountyMap
