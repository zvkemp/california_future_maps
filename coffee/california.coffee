class CountyMap
  constructor: ->

    height = 960
    width  = 1160

    svg = d3.select('body').append('svg')
      .attr('width', width)
      .attr('height', height)

    d3.json('data/cali.json', (error, counties) ->
      console.log(counties)
      window.counties = counties
      svg.append('path')
        .datum(topojson.feature(counties, counties.objects.california_counties))
        .attr("d", d3.geo.path().projection(d3.geo.mercator()))
    )

new CountyMap
