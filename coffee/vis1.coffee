# ---
# Creates new BubbleChart class.
# ---
class BubbleChart
  rValue = (d) -> parseInt(d.count)

  constructor: (data) ->
    @width = 940
    @height = 600
    @margin = {top: 5, right: 0, bottom: 0, left: 0}

    # used for setting up force and moving nodes
    @layout_gravity = 0.1
    @damper = 0.1
    @force = null

    @data = data
    @nodes = []
    @svg = null
    @circles = null
    @labels = null

    max_radius = d3.max(@data, (d) -> rValue(d)) # largest size for our bubbles
    # this scale will be used to size our bubbles
    @radius_scale = d3.scale.sqrt().range([0,max_radius])

    # variables that can be changed
    # to tweak how the force layout
    # acts
    # - jitter controls the 'jumpiness'
    #  of the collisions
    jitter = 0.5

    this.create_nodes()
    this.create_vis()

  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.name
        radius: @radius_scale(rValue(d))
        label: d.name
      }
      @nodes.push node

  # ---
  # adds mouse events to element
  # ---
  connectEvents = (d) ->
    d.on("click", click)
     .on("mouseover", mouseover)
     .on("mouseout", mouseout)

  # ---
  # clears currently selected bubble
  # ---
  clear = () ->
    location.replace("#")

  # ---
  # changes clicked bubble by modifying url
  # ---
  click = (d) ->
    location.replace("#" + encodeURIComponent(idValue(d)))
    d3.event.preventDefault()

  # ---
  # called when url after the # changes
  # ---
  hashchange = () ->
    id = decodeURIComponent(location.hash.substring(1)).trim()
    updateActive(id)

  # ---
  # activates new node
  # ---
  updateActive = (id) ->
    @circles.classed("bubble-selected", (d) -> id == d.id)
    # if no node is selected, id will be empty
    if id.length > 0
      d3.select("#status").html("<h3>The word <span class=\"active\">#{id}</span> is now active</h3>")
    else
      d3.select("#status").html("<h3>No word is active</h3>")

  # ---
  # hover event
  # ---
  mouseover = (d) ->
    @circles.classed("bubble-hover", (p) -> p == d)

  # ---
  # remove hover class
  # ---
  mouseout = (d) ->
    @circles.classed("bubble-hover", false)

  create_vis: () =>
    # a fancy way to setup svg element
    @svg = d3.selectAll("#vis").data([]).enter()
      .append("svg")
        .attr("id", "svg_vis")
        .attr("width", @width + @margin.left + @margin.right )
        .attr("height", @height + @margin.top + @margin.bottom )

    # node will be used to group the bubbles
    @circles = @svg.append("g")
                 .attr("id", "bubble-nodes")
                 .attr("transform", "translate(#{@margin.left},#{@margin.top})")

    # clickable background rect to clear the current selection
    @circles.append("rect")
              .attr("id", "bubble-background")
              .attr("width", @width)
              .attr("height", @height)
              .on("click", clear)

    # label is the container div for all the labels that sit on top of
    # the bubbles
    # - remember that we are keeping the labels in plain html and
    #  the bubbles in svg
    @label = @svg.selectAll("#bubble-labels").data([]).enter()
      .append("div")
        .attr("id", "bubble-labels")

    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    @circles = @circles.selectAll(".bubble-node").data(@nodes, (d) -> d.id)

    # nodes are just links with circles inside.
    # the styling comes from the css
    @circles.enter()
      .append("a")
        .attr("class", "bubble-node")
        .attr("xlink:href", (d) -> "##{encodeURIComponent(d.id)}")
        .call(@force.drag)
        .call(connectEvents)
        .append("circle")
          .attr("r", (d) -> d.radius)

    @label = @label.selectAll(".bubble-label").data(@nodes, (d) -> d.id)

    @label.exit().remove()

    # labels are anchors with div's inside them
    # labelEnter holds our enter selection so it
    # is easier to append multiple elements to this selection
    @labelEnter = @label.enter()
      .append("a")
        .attr("class", "bubble-label")
        .attr("href", (d) -> "##{encodeURIComponent(idValue(d))}")
        .call(@force.drag)
        .call(connectEvents)

    @labelEnter.append("div")
      .attr("class", "bubble-label-name")
      .text((d) -> d.label)

    @labelEnter.append("div")
      .attr("class", "bubble-label-value")
      .text((d) -> d.radius)

    # label font size is determined based on the size of the bubble
    # this sizing allows for a bit of overhang outside of the bubble
    # - remember to add the 'px' at the end as we are dealing with
    #  styling divs
    @label.style("font-size", (d) -> Math.max(8, d.radius / 2) + "px")
          .style("width", (d) -> 2.5 * d.radius + "px")

    # interesting hack to get the 'true' text width
    # - create a span inside the label
    # - add the text to this span
    # - use the span to compute the nodes 'dx' value
    #  which is how much to adjust the label by when
    #  positioning it
    # - remove the extra span
    @label.append("span")
      .text((d) -> d.label)
      .each((d) -> d.dx = Math.max(2.5 * d.radius, this.getBoundingClientRect().width))
      .remove()

    # reset the width of the label to the actual width
    @label.style("width", (d) -> d.dx + "px")

    # compute and store each nodes 'dy' value - the
    # amount to shift the label down
    # 'this' inside of D3's each refers to the actual DOM element
    # connected to the data node
    @label.each((d) -> d.dy = this.getBoundingClientRect().height)

    # see if url includes an id already
    hashchange()

    # automatically call hashchange when the url has changed
    d3.select(window)
      .on("hashchange", hashchange)

  # set the charge of each node
  #  - charge is proportional to the circle radius
  #  - charge is negative as nodes repel
  #  - dividing by alpha > 1 scales charge down
  charge: (d) ->
      -Math.pow(d.radius, 2.0) / 7

  # starts up the force layout with the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # sets up force layout to display all nodes
  display_all: () =>
    @force.gravity(layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .size([@width, @height])
      .on "tick", (e) =>
        @circles.attr("transform", (d) -> "translate(#{d.x},#{d.y})")
        # as the labels are created in raw html and not svg, we need
        # to ensure we specify the 'px' for moving based on pixels
        label.style("left", (d) -> ((@margin.left + d.x) - d.dx / 2) + "px")
             .style("top", (d) -> ((@margin.top + d.y) - d.dy / 2) + "px")
    @force.start()

# ---
# jQuery document ready.
# ---
root = exports ? this

$ ->
  chart = null

  # ---
  # function that is called when
  # data is loaded
  # ---
  render_vis = (csv) ->
    chart = new BubbleChart csv
    #chart.start()
    chart.display_all()

  # load our data
  d3.csv "data/alice.csv", render_vis
