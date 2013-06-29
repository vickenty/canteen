$(function() {
    $("#votelist .push_button").each(function() {
        var $parent = $(this).parent();
        var $input = $parent.find('input');
        var $buttons = $parent.find('.push_button');

        $(this).bind('click touchstart', function (ev) {
            var was_selected = $(this).hasClass('active');

            $buttons.removeClass('active');

            if (was_selected) {
                $input.val('');
            } else {
                $input.val($(this).data('vote'));
                $(this).addClass('active');
            }

            return false;
        });
    });

    $("#submit_button").bind('click', function(ev) {
        var $button = $(this);
        $button.addClass('pushed_in');

        setTimeout(function() {
            $button.removeClass('pushed_in');
        }, 100);

        $button.text($button.data('sent'));

        setTimeout(function() {
            $button.text($button.data('normal'));
        }, 3000);
    });

    $('form').bind('vote:sent', function() {
        $(this).find('input').val('');
        $(this).find('.push_button').removeClass('active');
    });
});
