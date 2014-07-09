id    = (d) -> d
value = (d) -> d.value
text  = (d) -> d.text

class CountyMapControls
  constructor: (map, meta) ->
    controls = d3.select('body').append('div')

    years = controls.append('select')
    years.selectAll('option').data(meta.year).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    ages = controls.append('select')
    age_data = [{ value: "all", text: "all Age groups" }].concat({ value: g, text: "#{g.replace("..", " to ")} year olds" } for g in meta.age_group)
    ages.selectAll('option').data(age_data)
      .enter()
      .append('option')
      .attr('value', value)
      .text(text)

    races = controls.append('select')
    races.selectAll('option').data(["all"].concat meta.race).enter()
      .append('option')
      .attr('value', id)
      .text(id)

    zoom = controls.append('select')
    zoom.selectAll('option').data([{ text: "Bay Area", value: 14000 }, { text: "California", value: 4500 }]).enter()
      .append('option')
      .attr('value', value)
      .text(text)

    zoom.on('change', -> map.zoom(zoom.node().value))

    #selectedYear = -> years.select('input:checked').node().value
    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    changeEvent  = -> map.loadPopulationData(selectedYear(), selectedRace(), selectedAge())
    selector.on('change', changeEvent) for selector in [years, races, ages]
    map.onLoad = changeEvent

class window.CountyMap
  height: 800
  width: 1100

  onLoad: ->

  constructor: (meta, options = { mode: "percent_population" }) ->
    #@appendControls(meta)
    @svg = d3.select('#main').append('svg')
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
    @_meta = meta
    modes = [
      {
        mode: "percent_population"
        name: "Demographic Cohorts"
        description:
          "For each selectable age category and ethnic group, shows the 
          percentage of that groups representation in each county. Projections made by
          the California Department of Finance Demographic Research Unit."
      }, {
        mode: "percent_change"
        name: "Change in Demographic Cohorts"
        description:
          "For each selectable age category and ethnic group, shows the change in percentage
          for each county over a 50-year period."
      }, {
        mode: "income"
        name: "Median Household Income"
        description:
          "Median household income by county.
           Data from the American Community Survey (US Census Dept) 2012 5-year Estimates."
      }, {
        mode: "density"
        name: "Population Density"
        description:
          "Raw population estimates divided by the area of the county.
          Data from the American Community Survey (US Census Dept) 2012 5-year Estimates."
      }
    ]

    table = d3.select('#main').append('table').attr('id', 'mode_selection')
    table.append('thead')
    tbody = table.append('tbody')
    @modeSelection = tbody.append('tr')
    @modeSelection.selectAll('td.button').data(modes)
      .enter()
      .append('td').attr('class', 'button')
      .text((d) -> d.name)
      .on('click', (d) => @changeMode(d.mode))
    tr = tbody.append('tr')
    tr.selectAll('td.description').data(modes)
      .enter()
      .append('td').attr('class', 'description')
      .text((d) -> d.description)


    d3.json('data/cali.json', (error, counties) =>
      #topojson.presimplify(counties, -> 100)
      @appendCounties(counties)
      @appendOutline(counties)
      @appendHoverLayer(counties)
      @appendZoomControls()
      @changeMode(options.mode)
    )


  setModeSelectorClass: ->
    @modeSelection.selectAll('td.button')
      .classed('active', (d) => d.mode is @_mode)

  mode: (d) ->
    if d
      @_mode = d
      return @
    @_mode

  changeMode: (mode) ->
    @_mode = mode
    @colors = @_colors[@_mode]
    @legend.remove() if @legend
    @liveLegend.remove() if @liveLegend
    @["appendLegend_#{@_mode}"]()
    @["appendLiveLegend_#{@_mode}"]()
    @onLoad()
    @setModeSelectorClass()


  _colors: {
    percent_change: d3.scale.linear()
      .domain([-1, -0.25, 0, 0.25, 1])
      .range(['#e74c3c', '#e74c3c', 'white', '#2ecc71', '#2ecc71'])
    percent_population: d3.scale.linear()
      .domain([0, 0.25, 1])
      .range(['#fff', '#3498DB', '#E74C3C'])
    income: d3.scale.linear()
      .domain([0, 30000, 50000, 100000])
      .range(['white', 'white', '#f1c40f', '#e74c3c'])
    density: d3.scale.linear()
      .domain([0, 2000, 5000, 20000]) #, 20000])
      .range(['white', '#3498db', '#1ABC9C', '#1ABC9C']) #, '#9b59b6'])
  }

  animateOnce: ->
    years = @_meta.year.concat([])
    intId = null
    animate = =>
      if years.length is 0
        clearInterval(intId)
        return
      year = years.shift()
      @years.select("option[value=\"#{year}\"]").attr('selected', 'selected')
      @changeEvent()
    intId = setInterval(animate, 500)

  animate: ->
    years = @_meta.year
    #years = [2010, 2060]
    ylength = years.length
    index = 0
    animate = =>
      year = years[index % years.length]
      index++
      @years.select("option[value=\"#{year}\"]").attr('selected', 'selected')
      @changeEvent()
    @repId = setInterval(animate, 250)

  stopAnimation: -> 
    clearInterval(@repId)
    @repId = null

  appendLiveLegend_income: -> @loadPopulationData()

  appendLiveLegend_percent_population: ->
    @_legendWrapper = @svg.append('foreignObject').attr('x', 40).attr('y', @height - 150).attr('width', 360).attr('height', 200)
    @liveLegend = @_legendWrapper.append('xhtml:div')

    large_text = @liveLegend.append('p').attr('class', 'large')
    small_text = @liveLegend.append('p').attr('class', 'small')
    small_text.append('span').text('AS A PERCENTAGE OF THE TOTAL,')
    years = small_text.append('select').attr('class', 'small')
    years.selectAll('option').data(@_meta.year).enter()
      .append('option')
      .attr('value', id)
      .text(id)
    @years = years
    small_text.append('span').text('ESTIMATE')

    races = large_text.append('select').attr('class', 'large')
    race_data = [{ value: "all", text: "All Ethnicities" }].concat({ value: g, text: g} for g in @_meta.race)
    races.selectAll('option').data(race_data).enter()
      .append('option')
      .attr('value', value)
      .text(text)
    large_text.append('span').text(",")

    ages = large_text.append('select').attr('class', 'large')
    age_data = [{ value: "all", text: "All Age Groups" }].concat({ value: g, text: "#{g.replace("..", " to ")} year olds" } for g in @_meta.age_group)
    ages.selectAll('option').data(age_data)
      .enter()
      .append('option')
      .attr('value', value)
      .text(text)

    selectedYear = -> years.node().value
    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    @changeEvent  = -> map.loadPopulationData(selectedYear(), selectedRace(), selectedAge())
    selector.on('change', @changeEvent) for selector in [years, races, ages]

    # look at 18..44 year olds by default
    ages.select('option[value="18..44"]').attr('selected', 'selected')
    map.onLoad = @changeEvent

  appendLiveLegend_percent_change: ->
    @_legendWrapper = @svg.append('foreignObject').attr('x', 40).attr('y', @height - 150).attr('width', 360).attr('height', 200)
    @liveLegend = @_legendWrapper.append('xhtml:div')

    large_text = @liveLegend.append('p').attr('class', 'large')
    small_text = @liveLegend.append('p').attr('class', 'small')
    small_text.append('span').text('2010-2060 CHANGE IN PERCENTAGE OF THE TOTAL')

    races = large_text.append('select').attr('class', 'large')
    race_data = [{ value: "all", text: "All Ethnicities" }].concat({ value: g, text: g} for g in @_meta.race)
    races.selectAll('option').data(race_data).enter()
      .append('option')
      .attr('value', value)
      .text(text)
    large_text.append('span').text(",")

    ages = large_text.append('select').attr('class', 'large')
    age_data = [{ value: "all", text: "All Age Groups" }].concat({ value: g, text: "#{g.replace("..", " to ")} year olds" } for g in @_meta.age_group)
    ages.selectAll('option').data(age_data)
      .enter()
      .append('option')
      .attr('value', value)
      .text(text)

    selectedRace = -> races.node().value
    selectedAge  = -> ages.node().value
    @changeEvent  = -> map.loadPopulationData(2010, selectedRace(), selectedAge())
    selector.on('change', @changeEvent) for selector in [races, ages]

    # look at 18..44 year olds by default
    ages.select('option[value="18..44"]').attr('selected', 'selected')
    map.onLoad = @changeEvent

  appendZoomControls: ->
    @_zoomControlWrapper = @svg.append('foreignObject')
      .attr('x', 40)
      .attr('y', @height - 40)
      .attr('width', 330)
      .attr('height', 200)
    zoomControl = @_zoomControlWrapper.append('xhtml:div')
      .style('font-size', '10pt')
    zoomControl.append('span').text('ZOOM TO:')
    zoom = zoomControl.append('select').attr('class', 'small')
    zoom.selectAll('option').data([{ text: "Bay Area", value: 14000 }, { text: "California", value: 4500 }])
      .enter()
      .append('option')
      .attr('value', value)
      .text(text)
    zoom.on('change', -> 
      map.zoom(zoom.node().value)
    )

  appendLegend_percent_change: ->
    @legend = @svg.append('g').attr('id', 'legend')
      .attr('transform', "translate(30, #{@height - 100})")
    legendX = (d) -> 600 * d + 160
    legendData = (n for n in [-0.25..0.25] by 0.05)
    #legendData = [-0.25, -0.2, -0.15, -0.1, -0.05, 0, 0.05, 0.10, 0.15, 0.2, 0.25]
    #legendData = ["-25-", "-20", "-15", "-10", "-5", "0", "5", "10", "15", "20", "25+"]
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


  appendLegend_income: ->
    @legend = @svg.append('g').attr('id', 'legend')
      .attr('transform', "translate(30, #{@height - 100})")
    legendX = (d) -> 30 * d / 10000 - 90
    legendData = (n for n in [30000..100000] by 10000)
    @legend.selectAll('rect').data(legendData)
      .enter()
      .append('rect')
      .attr('x', legendX)
      .attr('y', 10)
      .attr('width', 30)
      .attr('height', 30)
      .style('stroke', 'white')
      .style('fill', @colors)
    format = d3.format("0,000")
    @legend.selectAll('text.income').data(legendData)
      .enter()
      .append('text')
      .attr('transform', (d) -> "translate(#{legendX(d) + 15}, 50)")
      .text((d) -> "#{d/1000}K")
      .style('text-anchor', 'middle')
      .style('font-size', 10)
      .style('font-weight', 'bold')
    large_text = @legend.append('text').text("Median Household Income").attr('class', 'large')
      .attr('transform', "translate(0, -35)")
    small_text = @legend.append('text').text('IN US DOLLARS').attr('class', 'small')
      .attr('transform', "translate(0, -20)")
    source = @legend.append('text').text('SOURCE: American Community Survey, 2012 5-Year Estimates')
      .style('font-size', '8pt')

  appendLegend_percent_population: ->
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

  appendLegend_density: -> 
    @legend = @svg.append('g').attr('id', 'legend')
      .attr('transform', "translate(30, #{@height - 100})")
    legendX = (d) -> 30 * d / 500
    legendData = (n for n in [0..5000] by 500)
    @legend.selectAll('rect').data(legendData)
      .enter()
      .append('rect')
      .attr('x', legendX)
      .attr('y', 10)
      .attr('width', 30)
      .attr('height', 30)
      .style('stroke', 'white')
      .style('fill', @colors)
    format = (d) -> "#{d/1000}K"
    @legend.selectAll('text.density').data(legendData)
      .enter()
      .append('text')
      .attr('transform', (d) -> "translate(#{legendX(d) + 15}, 50)")
      .text(format)
      .style('text-anchor', 'middle')
      .style('font-size', 10)
      .style('font-weight', 'bold')
    large_text = @legend.append('text').text("Population Density").attr('class', 'large')
      .attr('transform', "translate(0, -35)")
    small_text = @legend.append('text').text('PER SQUARE MILE').attr('class', 'small')
      .attr('transform', "translate(0, -20)")
    source = @legend.append('text').text('SOURCE: American Community Survey, 2012 5-Year Estimates')
      .style('font-size', '8pt')


  appendLiveLegend_density: -> @loadPopulationData()

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
    @stopAnimation() if @repId
    @projection.scale(scale)
    @path.projection(@projection)
    @counties.selectAll('path').transition().duration(1000).attr('d', @path)
    @hoverLayer.selectAll('path').attr('d', @path)
    @hoverLayer.selectAll('text.name')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1])
    @hoverLayer.selectAll('text.value')
      .attr('x', (d) => @path.centroid(d)[0])
      .attr('y', (d) => @path.centroid(d)[1] + 15)
    @outline.transition().duration(1000).attr('d', @path)
    @bay_area.transition().duration(1000).attr('d', @path)

  appendCounties: (counties) =>
    # This seems a little convuluted, but all is necessary to provide nice, non-overlapping
    # tooltips (outlines and county metadata) on mouseover.
    # topojson.presimplify(counties)
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

  _load_by_percent_population: (year, race, age) ->
    @_requestData(year, race, age, (data) =>
      @_requestData(year, "all", "all", (totals) =>
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

  _load_by_percent_change: (year, race, age) ->
    @_requestData(2010, race, age, (data2010) =>
      @_requestData(2060, race, age, (data2060) =>
        @_requestData(2010, 'all', 'all', (total2010) =>
          @_requestData(2060, 'all', 'all', (total2060) =>
            pop                           = {}
            (pop[row.county]              = row) for row in data2010
            (pop[row.county].total2010    = row.estimate) for row in total2010
            (pop[row.county].estimate2060 = row.estimate) for row in data2060
            (pop[row.county].total2060    = row.estimate) for row in total2060

            colorWrapper = (value) =>
              @colors(percentageChange(value))

            percentageChange = (d) ->
              p = pop[d.properties.name]
              (p.estimate2060 / p.total2060) - (p.estimate / p.total2010)
              #(p.estimate2060 - p.estimate) / p.estimate

            @counties.selectAll('path.fill').transition().style('fill', (d) => @colors(percentageChange(d)))
            @hoverLayer.selectAll('text.value')
              .text((d) -> "#{d3.round(100 * percentageChange(d), 1)}%")

          )
        )
      )
    )

  _load_by_income: (year, race, age) =>
    d3.csv('income.csv', (data) =>
      pop              = {}
      (pop[row.county] = row) for row in data
      medianIncome     = (d) -> pop[d.properties.name].median_income
      format           = d3.format("0,000")

      #@colors.domain([0].concat(d3.extent(data.map((d) -> d.median_income))))
      @counties.selectAll('path.fill').transition().style('fill', (d) => @colors(medianIncome(d)))
      @hoverLayer.selectAll('text.value')
        .text((d) -> "$#{format(medianIncome(d))}")

    )

  _load_by_density: (year, race, age) =>
    d3.csv('population.csv', (data) =>
      d3.csv('data/square_miles.csv', (area) =>

        pop                = {}
        areas              = {}
        (pop[row.county]   = row) for row in data
        (areas[row.county] = row.square_miles) for row in area
        (row.density       = Math.round(row.population / areas[county])) for county, row of pop
        density            = (d) -> pop[d.properties.name].density
        format             = d3.format("0,000")
        #@colors.domain(d3.extent(row.density for _, row of pop))

        @counties.selectAll('path.fill').transition().style('fill', (d) => @colors(density(d)))
        @hoverLayer.selectAll('text.value').text((d) -> "#{format(density(d))} / sq. mile")
      )
    )


  loadPopulationData: (year, race, age) =>
    age or= "all"
    @["_load_by_#{@_mode}"](year, race, age)

    # d3.json("/data.json?year=#{year}&race=#{race}&age_group=#{age}&gender=all", (data) =>
    #   d3.json("/data.json?year=#{year}&race=all&age_group=all&gender=all", (totals) =>
    #     pop = {}
    #     (pop[row.county] = row) for row in data
    #     (pop[row.county].total = row.estimate) for row in totals

    #     colorWrapper = (value) =>
    #       @colors(percentageOfTotal(value))

    #     percentageOfTotal = (d) ->
    #       p = pop[d.properties.name]
    #       p.estimate / p.total

    #     @counties.selectAll('path.fill').transition().style('fill', (d) =>
    #       @colors(percentageOfTotal(d))
    #     )
    #     @hoverLayer.selectAll('text.value')
    #       .text((d) -> "#{d3.round(100 * percentageOfTotal(d), 1)}%")
    #     #@legendTextContent(year, race, age)
    #   )
    # )

  _requestData: (year, race, age, callback) ->
    @_cache or= {}
    if (data = @_cache[[year, race, age]])
      callback(data)
    else
      d3.json("/data.json?year=#{year}&race=#{race}&age_group=#{age}&gender=all", (data) =>
        @_cache[[year, race, age]] = data
        callback(data)
      )


#d3.json("/meta.json", (meta) ->
#window.map = new CountyMap(meta)
#)
