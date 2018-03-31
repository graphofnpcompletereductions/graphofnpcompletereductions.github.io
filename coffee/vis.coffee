# ---
# Creates new BubbleChart class.
# ---
class BubbleChart
    constructor: (data) ->
        @data = data
        @width = 940
        @height = 500

        # colors associated with each problem type
        @fill_color = d3.scale.ordinal()
            .domain(["LG", "GT", "ND", "SP", "MISC"])
            .range(["#E8E98F", "#C18FE9", "#E991BF", "#8FD2E9", "#E9B98F"])

        # locations the nodes will move towards
        @center = {x: @width/2, y: @height/2}

        # used when setting up force and moving around nodes
        @layout_gravity = 0.1
        @damper = 0.1

        # these will be set in create_nodes and create_vis
        @nodes = []
        @edges = []
        @force = null

        @vis = null
        @background = null
        @links = null
        @node_group = null
        @circles = null
        @labels = null
        @current = {data: null, i: null, element: null}

        this.create_nodes()
        this.create_edges()
        this.create_vis()

    # create node objects from original data
    # that will serve as the data behind each
    # bubble in the vis, then add each node
    # to @nodes to be used later
    create_nodes: () =>
        @data.forEach (d) =>
            node = {
                id: parseInt(d.id)
                name: d.name
                abbrev: d.abbrev
                parent: parseInt(d.reducedfrom)
                nbours: []
                input: d.input
                question: d.question
                reference: d.reference
                tag: d.tags
                color: @fill_color(d.tags)
                comment: d.comment
                radius: 0
                x: Math.random() * 900
                y: Math.random() * 800
            }
            @nodes.push node
        @nodes.sort (a,b) => a.id - b.id

        # computes the degree of each node and
        # uses this to assign a radius to each node
        # linear in its degree
        degree = Array(@nodes.length)
        @nodes.forEach (n) =>
            if degree[n.id] == undefined
                degree[n.id] = 1
            else
                degree[n.id]++
            if n.parent >= 0
                if degree[n.parent] == undefined
                    degree[n.parent] = 1
                else
                    degree[n.parent]++

        # use the max degree of node as the max in the scale's domain
        max_amount = d3.max(degree)
        @radius_scale = d3.scale.linear().domain([0, max_amount]).range([10, 60])

        @nodes.forEach (n) =>
            n.radius = @radius_scale(degree[n.id])

    create_edges: () =>
        for node in @nodes
            if node.parent >= 0
                @edges.push {source: node, target: @nodes[node.parent]}
                @nodes[node.parent].nbours.push node.id

    # Create svg at #vis and then
    # creates a node group for each node. Each
    # node group consists of a circle and
    # its associated text.
    create_vis: () =>
        @vis = d3.select("#vis").append("svg")
          .attr("width", @width)
          .attr("height", @height)

        @background = @vis.append("rect")
          .attr("id", "bubble-background")
          .attr("width", @width)
          .attr("height", @height)

        @start()
        @display_all()

        # used because we need 'this' in the
        # mouse callbacks
        that = this

        @links = @vis.selectAll(".link").data(@edges).enter()
          .append("line")
            .attr("class", "link")

        @node_group = @vis.selectAll(".bubble-node")
          .data(@nodes, (d) -> d.id)
          .enter()
          .append("g")
            .attr("class", "bubble-node")
            .attr("fill", (d) => d3.rgb(d.color))
            .call(@force.drag)
            .on("click", (d,i) -> that.show_details(d,i,this))
            .on("mouseover", (d,i) -> that.mouse_over(d,i,this))
            .on("mouseout", (d,i) -> that.mouse_out(d,i,this))
        @circles = @node_group.append("circle")
          .attr("r", (d) -> d.radius)
          .attr("id", (d) -> "bubble_#{d.id}")
        @labels = @node_group.append("text")
          .attr("text-anchor", "middle")
          .attr("class", "bubble-label")
          .text((d) -> d.abbrev)

        @background.on "click", (d,i) =>
            @deselect(@current.data, @current.i, @current.element)
            d3.select("#status").html("")
        #@node_group.call(d3.zoom()
        #        .scaleExtent([1/2, 4])
        #        .on("zoom", zoomed))

    # Starts up the force layout with
    # the default values
    #start: () =>
    #    @force = d3.forceSimulation(@nodes)
    #      .force("link", d3.forceLink(@edges).distance(100).strength(2))
    #      .force("center", d3.forceCenter(@width/2, @height/2))
    #      .force("charge", d3.forceManyBody())
    #      .on "tick", () =>
    #          #@circles.each(this.move_towards_center(e.alpha))
    #          @node_group.attr("transform", (d) -> "translate("+d.x+","+d.y+")")
    #          @links.attr("x1", (d) -> d.source.x)
    #            .attr("y1", (d) -> d.source.y)
    #            .attr("x2", (d) -> d.target.x)
    #            .attr("y2", (d) -> d.target.y)
    start: () =>
        @force = d3.layout.force()
          .nodes(@nodes)
          .links(@edges)
          .linkDistance(100)
          .size([@width, @height])

    # Sets up force layout to display
    # all nodes in one circle.
    display_all: () =>
        @force.gravity(@layout_gravity)
          .charge(this.charge)
          .friction(0.9)
          .on "tick", (e) =>
            @circles.each(this.move_towards_center(e.alpha))
            @node_group.attr("transform", (d) -> "translate("+d.x+","+d.y+")")
            @links.attr("x1", (d) -> d.source.x)
              .attr("y1", (d) -> d.source.y)
              .attr("x2", (d) -> d.target.x)
              .attr("y2", (d) -> d.target.y)
        @force.start()

    # Charge function that is called for each node.
    # Charge is proportional to the diameter of the
    # circle (which is stored in the radius attribute
    # of the circle's associated data.
    # This is done to allow for accurate collision
    # detection with nodes of different sizes.
    # Charge is negative because we want nodes to
    # repel.
    # Dividing by 2 scales down the charge to be
    # appropriate for the visualization dimensions.
    charge: (d) ->
        -Math.pow(d.radius, 2.0)

    # Moves all circles towards the @center
    # of the visualization
    move_towards_center: (alpha) =>
        (d) =>
            d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
            d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

    show_details: (data, i, element) =>
        @deselect(@current.data, @current.i, @current.element)
        @select(data, i, element)
        @current.data = data
        @current.i = i
        @current.element = element

        content = "<span class=\"name\" id=\"name-value\"><h4>#{data.name} [#{data.abbrev}]</h4></span><br/>"
        content +="<span id=\"input-value\"><b>Instance: </b> #{data.input}</span><br/>"
        content +="<span id=\"question-value\"><b>Question: </b> #{data.question}</span><br/>"
        if data.comment.length > 0
            content +="<span class=\"comment-value\"><b>Comments: </b> #{data.comment}</span><br/>"
        content +="<br/><span class=\"value\" id=\"reference-value\">#{data.reference}</span>"
        d3.select("#status").html(content)
        MathJax.Hub.Queue(['Typeset', MathJax.Hub, "name-value"])
        MathJax.Hub.Queue(['Typeset', MathJax.Hub, "input-value"])
        MathJax.Hub.Queue(['Typeset', MathJax.Hub, "question-value"])
        MathJax.Hub.Queue(['Typeset', MathJax.Hub, "comment-value"])

    deselect: (data, i, element) =>
        if element != null
            @remove_class_from_node("bubble-selected")
            @remove_class_from_node("bubble-parent")
            @remove_class_from_node("bubble-nbour")

            @links.classed("show-link", false)
              .attr("stroke", "")
            @links.classed("show-link-parent", false)
              .attr("stroke", "")

    remove_class_from_node: (class_name) =>
        @node_group.classed(class_name, false)
          .select("circle")
            .attr("stroke", "")
            .attr("fill", (d) -> d.color)

    select: (data, i, element) =>
        @node_group.classed("bubble-selected", (d) -> d.id == data.id)
        @node_group.classed("bubble-parent", (d) -> data.parent != null and d.id == data.parent)
        @node_group.classed("bubble-nbour", (d) -> d.id in data.nbours)
        @style_node("bubble-selected", "black", 4)
        @style_node("bubble-parent", "red", 2)
        @style_node("bubble-nbour", "black", 1)

        @links.classed("show-link", (d) -> d.source.id in data.nbours and d.target.id == data.id)
        d3.selectAll(".show-link")
            .attr("stroke", "black")
            .attr("stroke-width", 1)
        @links.classed("show-link-parent", (d) -> d.source.id == data.id and d.target.id == data.parent)
        d3.selectAll(".show-link-parent")
            .attr("stroke", "red")
            .attr("stroke-width", 2)

    style_node: (class_name, color, width) =>
        d3.selectAll("." + class_name)
          .select("circle")
            .attr("stroke", color)
            .attr("stroke-width", width)
            .attr("fill", (d) -> d3.rgb(d.color).darker())

    mouse_over: (data, i, element) =>
        if not @is_selected(element, "bubble-selected") and
           not @is_selected(element, "bubble-parent") and
           not @is_selected(element, "bubble-nbour")
            d3.select(element)
                .select("circle")
                  .attr("fill", (d) -> d3.rgb(d.color).brighter())

    mouse_out: (data, i, element) =>
        if not @is_selected(element, "bubble-selected") and
           not @is_selected(element, "bubble-parent") and
           not @is_selected(element, "bubble-nbour")
            d3.select(element)
                .select("circle")
                  .attr("fill", (d) -> d.color)

    is_selected: (element, cname) =>
        return d3.select(element).classed(cname)

    #zoomed: () =>
    #    @node_group.attr("transform", d3.event.transform)


root = exports ? this

$ ->
    chart = null
    render_vis = (csv) ->
        chart = new BubbleChart csv
    d3.csv "data/annotatedListData.csv", render_vis
