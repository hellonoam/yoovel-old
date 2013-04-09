window.width = $(window).width()

window.now = -> Math.round(new Date().getTime() / 1000)

class window.Result
  @touchHandler = (event) ->
    return unless event.target.draggable
    touches = event.changedTouches
    first = touches[0]
    type = ""

    switch event.type
      when "touchstart" then type = "mousedown"
      when "touchmove" then type = "mousemove"
      when "touchend" then type = "mouseup"
      else return
    simulatedEvent = document.createEvent("MouseEvent")
    simulatedEvent.initMouseEvent(type, true, true, window, 1,
                            first.screenX, first.screenY,
                            first.clientX, first.clientY, false,
                            false, false, false, 0, null)

    first.target.dispatchEvent(simulatedEvent);
    event.preventDefault();

  @init = =>
    # this is for the slide to open funcationality.
    document.addEventListener("touchstart", @touchHandler, true)
    document.addEventListener("touchmove", @touchHandler, true)
    document.addEventListener("touchend", @touchHandler, true)
    document.addEventListener("touchcancel", @touchHandler, true)

    mixpanel.track_links("a.track", "clicked a link", (elem) -> type: $(elem).attr("data-track-name"))

    $(".appImageWrapper img").draggable(
        axis: 'x'
        drag: (event, ui) ->
          $(this).parent().parent().find(".info").css("opacity", 1 - (ui.position.left / 300))
        stop: (event, ui) ->
          # for some reason window.width give the wrong size for mobile
          if (200) < ui.position.left
            $a = $(this).closest("a")
            mixpanel.track("clicked a link", { type: $a.attr("data-track-name") }, ->
              url = $a.attr("href")
              # for now just always open the page in the same page. since some browsers block that.
              if false && url.match /^http/
                window.open(url, '_blank')
              else
                window.location = url
            )
          $(this).animate({"left": "0px"}, 400)
          $(this).parent().parent().find(".info").animate({"opacity": "1"}, 400)
    )

class window.Search
  @TIME_TILL_LOCATION_AVAIL = 500
  @SEARCH_INTERVAL = 1000

  @performSearch = ->
    @performedLastQuery = @$search.val()
    return if @performedLastQuery == ""

    history.pushState({}, document.title, "/?q=#{@performedLastQuery}")
    $.ajax(
      url: "/search"
      type: "GET"
      data:
        q: @performedLastQuery
        lat: window.latitude
        long: window.longitude
      success: (data) ->
        $(".list").html(data)
    )

  @init = (q) =>
    @$search = $(".search")
    @$search.val(q)
    setTimeout((=> @performSearch()), @TIME_TILL_LOCATION_AVAIL) if q isnt ""
    # Not loading finger blast for since we're not using ratchet.js anymore
    # new FingerBlast(".searchResults") unless $(".searchResults").length == 0

    # Might not be the best way to do this... but works well
    setInterval(
      (=> if @$search.val().length > 2 and @performedLastQuery isnt @$search.val()
        @performSearch()
      ), @SEARCH_INTERVAL)
    @$search.keypress( (event) => @performSearch() if event.keyCode == 13)

# removes the annoying hashes facebook adds to the url after oauth
window.addEventListener("load", (e) ->
  if window.location.hash == "#_=_"
    window.location.hash = ""
    history.replaceState("", document.title, window.location.pathname + window.location.search)
    e.preventDefault()
)