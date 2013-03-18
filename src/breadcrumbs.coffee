if require? and module? # determine wether it's commonjs module
    async = require 'async'
    $ = require 'commonjs-jquery'

bs_item_s = '.bs-item'
bs_static = '.bs-static'

memoize_width = (item) -> $(item).data width: $(item).outerWidth()
read_width = (item) -> $(item).data().width

animation =
    hide: (item, cb) ->
        animate_cb = ->
            $(item).hide()
            cb()
        memoize_width item
        $(item).animate({width: "0px", opacity: 0}, animate_cb)

    show: (item, cb) ->
        $(item).show()
        $(item).animate({width: read_width(item), opacity: 1}, -> cb())


get_outer_width = (items) ->
    width_count_reduce_func = (a, b) ->
        a += ($ b).outerWidth()

    items.reduce width_count_reduce_func, 0


init = (breadcumbs_wrapper, expander_class, on_animation_start, on_animation_end) ->
    collapsable_items = $(breadcumbs_wrapper).find("#{bs_item_s}:not(#{bs_static})").toArray()
    static_items = ($ bs_static).toArray()

    expander = $(collapsable_items[0]).clone()
    expander.text '...'
    expander.css {cursor: "pointer"}
    expander.addClass expander_class

    process
        result_width: get_outer_width collapsable_items.concat static_items
        allowed_width: $(breadcumbs_wrapper).width()
        collapsable_items: collapsable_items
        static_items: static_items
        expander: expander
        on_animation_start: on_animation_start
        on_animation_end: on_animation_end


toggle_items = (collapsable_items, effect, action="show", cb) ->
    item_action = if effect?
        if action is "show"
            effect.show
        else
            effect.hide
    else
        if action is "show"
            (item, cb) ->
                $(item).show()
                cb()
        else
            (item, cb) ->
                $(item).hide()
                cb()

    async.map collapsable_items, item_action, (err, items) ->
        items.map (i) -> ($ i).hide()
        cb?()


show_expander = (expander, item_after) ->
    expander.insertAfter item_after


get_show_hide_items = (from_head=true, items, static_items, allowed_width) ->
    items.reverse()
    reduce_by_allowed_width = (a, b) ->
        [current_width, _items_to_hide, _items_to_show] = a

        new_width = ($ b).outerWidth() + current_width

        a = if new_width < allowed_width
            [new_width, _items_to_hide, _items_to_show.concat b]
        else
            [new_width, (_items_to_hide.concat b), _items_to_show]

    [width, items_to_hide, items_to_show] = items.reduce reduce_by_allowed_width, [get_outer_width(static_items), [], []]
    [items_to_hide, items_to_show]


process = ({result_width
            allowed_width
            static_items
            expander
            collapsable_items
            on_animation_start
            on_animation_end}) ->

    if result_width > allowed_width

        [from_head_hide_items, from_head_show_items] = get_show_hide_items(
            true, collapsable_items, static_items, allowed_width)

        [from_tail_hide_items, from_tail_show_items] = get_show_hide_items(
            false, collapsable_items, static_items, allowed_width)

        toggle_items(from_head_hide_items, animation
                     "hide"
            () -> show_expander expander, from_head_hide_items[0])

        from_head = true

        $(expander).click (ev) ->
            on_animation_start?()
            if from_head is true
                hide_from_head_visible = (cb) ->
                    toggle_items from_tail_hide_items, animation, "hide", () -> cb()

                expander_change_position = (cb) ->
                    show_expander expander, from_tail_show_items[-1..]
                    cb()

                show_from_tail_visible = (cb) ->
                    toggle_items from_tail_show_items, animation, "show", () ->
                        cb()

                async.parallel(
                    [
                        hide_from_head_visible
                        expander_change_position
                        show_from_tail_visible
                    ]
                    () ->
                        on_animation_end?()
                        from_head = false)
            else
                hide_from_tail_head_visible = (cb) ->
                    toggle_items from_head_hide_items, animation, "hide", () -> cb()

                expander_change_position = (cb) ->
                    show_expander expander, from_head_hide_items[0]
                    cb()

                show_from_tail_tail_visible = (cb) ->
                    toggle_items from_tail_hide_items, animation, "show", () -> cb()

                async.parallel(
                    [
                        hide_from_tail_head_visible
                        expander_change_position
                        show_from_tail_tail_visible
                    ]
                    () ->
                        on_animation_end?()
                        from_head = true)
if module?
    module.exports = init
