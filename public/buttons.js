$(function() {

	$("#votelist .push_button").bind('click touchstart', function () {
		// remove active class from all inputs within a meal type 
		// (go to parent, then identify all labels, remove class 'active' then all radios and deselect all)
		$(this).parent().find('.push_button').removeClass('active');
		$(this).parent().find('input').val($(this).data('vote'));

		// add 'active' class and select input on current element
		$(this).addClass('active');
	});

	
	$("#submit_button").click ( function () {
		$(this).addClass('pushed_in');	
	});
		
	
	setTimeout(function() {
	  var $button = $('#submit_button');
	  $button.text($button.data('normal'));
	}, 3000);

});
