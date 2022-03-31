app = new Object ();
app.tabs = new Object ();

app.tabs.init = function (limit_selector) {
    $(limit_selector + ' .tab-trigger').click(function () {
        var tab_group = $(this).data('tab-group');
        $(limit_selector + ' .tab-trigger.' + tab_group).removeClass('active');
        $(this).addClass('active');
        tab_id=$(this).data('tab');
        if (tab_id) {
            $('.' + tab_group + '.tab-content').hide();
            $('#' + tab_id).show();
        }
    });
};

app.page = new Object ();

app.page.set_min_height = function () {
    $('body').css('min-height', $('body').height() + 'px');
};

app.chart = new Object ();

app.chart.chroma_scale = chroma.scale([ '#14C8F6', '#FA5548', '#005480' ]).mode('lch');



/* POPUP */

;(function( $ ){

    var methods = {
        init: function() {
            if ($('#popup-overlay').length <= 0) {
                $('body').append('<div id="popup-overlay" class="popup-overlay"></div>');
            }
        },
        show: function() {
            $('#popup-overlay').show();

            $('#popup-overlay, .popup').bind('mousewheel DOMMouseScroll', function(event) {
                var scrollTo = null;
                if (event.type == 'mousewheel') {
                    scrollTo = (event.originalEvent.wheelDelta * -1);
                }
                else if (event.type == 'DOMMouseScroll') {
                    scrollTo = 40 * event.originalEvent.detail;
                }
                if (scrollTo) {
                    event.preventDefault();
                    $(this).scrollTop(scrollTo + $(this).scrollTop());
                }
            });

            var top=$(window).height() / 2 - $(this).outerHeight() / 2 - 20;
            var left=$(window).width() / 2 - $(this).outerWidth() / 2;
            top = top < 10 ? 10 : top;
            $(this).css('top', Math.floor(top) + 'px');
            $(this).css('left',  Math.floor(left) + 'px');
            $(this).css('max-width',  $(window).width() + 'px');
            $(this).show();
            $('body').addClass('scroll-disabled');
            try {
                $(this).find('input[type=text]')[0].focus();
            } catch (e) {}
        },
        hide: function() {
            $('#popup-overlay').hide();
            $('body').removeClass('scroll-disabled');
            $(this).hide();
        },
        remove: function() {
            $('#popup-overlay').hide();
            $('body').removeClass('scroll-disabled');
            $(this).remove();
        },
        update: function( content ) { }
    };
 
    $.fn.popup = function(methodOrOptions) {
        methods.init();
        if ( methods[methodOrOptions] ) {
            return methods[ methodOrOptions ].apply( this, Array.prototype.slice.call( arguments, 1 ));
        } else if ( typeof methodOrOptions === 'object' || ! methodOrOptions ) {
            return methods.init.apply( this, arguments );
        } else {
            $.error( 'Method ' +  method + ' does not exist on jQuery.popup' );
        }
    };

})( jQuery );

app.popup = {};

app.popup.simple = function (text, params) {
    var html_type = '';
    try {
        html_type = '<div class="title">' + params.type.charAt(0).toUpperCase() + params.type.slice(1) + '</div>';
    } catch (e) {}
    var html =
        '<div class="popup simple">'
            + html_type
            + text
            + '<div class="spacer-10"></div>'
            + '<input type="button" value="Close" onclick="$(this).parent().popup(\'remove\')">'
        +'</div>'
    ;
    var div = $(html).appendTo('body');
    div.popup('show');
};

/* Tooltips */

app.tooltip = {};

app.tooltip.init = function(selector) {
    if (selector === undefined) {
        selector = 'body';
    }
    $(selector+' .show-tooltip').mouseenter(function (ev) {
        createTip(ev.target);
    });
    $(selector+' .show-tooltip').mouseleave(function (ev) {
        cancelTip(ev.target);
    });
    $(selector+' .show-tooltip').on("DOMNodeRemovedFromDocument", function (ev) {
        cancelTip(ev.target);
    });

    function createTip(el) {
        var title = el.title;
        if (title === null || title === "") return; 
    
        el.title = '';
        el.setAttribute("tooltip", title);

        var tooltipWrap = document.createElement("div");
        tooltipWrap.className = 'tooltip';
        tooltipWrap.appendChild(document.createTextNode(title));

        var firstChild = document.body.firstChild;
        firstChild.parentNode.insertBefore(tooltipWrap, firstChild);
        var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        var linkProps = el.getBoundingClientRect();
        var linkWidth = el.offsetWidth;
        var tooltipProps = tooltipWrap.getBoundingClientRect();
        var topPos = scrollTop + linkProps.top - tooltipProps.height;
        var leftPos = linkProps.left + parseInt(linkWidth / 2) - parseInt(tooltipWrap.offsetWidth / 2);
        tooltipWrap.setAttribute('style','top:'+topPos+'px;'+'left:'+leftPos+'px;');
        $(tooltipWrap).mouseleave(function (tooltipWrap) {
            $('.tooltip').remove();
        });
    }

    function cancelTip(el) {
        var title = el.getAttribute("tooltip");
        if (title === null || title === "") return;

        el.title = title;
        el.removeAttribute("tooltip");
        $('.tooltip').remove();
    }
};