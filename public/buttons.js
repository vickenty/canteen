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

	
	$("#submit_button").click ( function () {
		$(this).addClass('pushed_in');	
	});
		
	
	setTimeout(function() {
	  var $button = $('#submit_button');
	  $button.text($button.data('normal'));
	}, 3000);

});
